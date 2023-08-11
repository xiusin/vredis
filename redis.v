module vredis

import net
import time
import sync
import strings

[params]
pub struct ConnOpts {
	read_timeout  time.Duration
	write_timeout time.Duration
	name          string
	port          int    = 6379
	host          string = '127.0.0.1'
	username      string
	requirepass   string
	db            int
}

const ok_flag = 'OK'

const nil_err = error('(nil)')

pub struct Redis {
	sync.Mutex
mut:
	socket   &net.TcpConn = unsafe { nil }
	prev_cmd string
	debug    bool
}

pub struct SetOpts {
	ex       int = -4
	px       int = -4
	nx       bool
	xx       bool
	keep_ttl bool
}

fn (mut r Redis) str() string {
	return r'vredis.Redis{}'
}

[inline]
fn (mut r Redis) is_nil(resp string) bool {
	return resp == '(nil)'
}

pub fn (mut r Redis) send(cmd string) !string {
	r.@lock()
	defer {
		r.unlock()
	}
	println('-> ${cmd}')
	r.write_string_to_socket(cmd)!
	return r.read_reply()!
}

pub fn (mut r Redis) write_string_to_socket(cmd string) ! {
	r.prev_cmd = cmd
	r.socket.write_string(cmd + '\r\n')!
}

// read_no_block
// @form net
fn (mut r Redis) read_no_block(max_line_len int) string {
	r.socket.set_blocking(false) or {}

	mut buf := [net.max_read]u8{} // where C.recv will store the network data
	mut res := strings.new_builder(net.max_read) // The final result, including the ending \n.
	defer {
		unsafe { res.free() }
	}
	bstart := unsafe { &buf[0] }
	for {
		n := C.recv(r.socket.sock.handle, bstart, net.max_read - 1, net.msg_peek | net.msg_nosignal)
		if n <= 0 {
			return res.str()
		}
		buf[n] = `\0`
		mut eol_idx := -1
		mut lend := n
		for i in 0 .. n {
			if buf[i] == `\n` {
				eol_idx = i
				lend = i + 1
				buf[lend] = `\0`
				break
			}
		}
		if eol_idx > 0 {
			// At this point, we are sure that recv returned valid data,
			// that contains *at least* one line.
			// Ensure that the block till the first \n (including it)
			// is removed from the socket's receive queue, so that it does
			// not get read again.
			C.recv(r.socket.sock.handle, bstart, lend, net.msg_nosignal)
			unsafe { res.write_ptr(bstart, lend) }
			break
		}
		// recv returned a buffer without \n in it, just store it for now:
		C.recv(r.socket.sock.handle, bstart, n, net.msg_nosignal)
		unsafe { res.write_ptr(bstart, lend) }
		if res.len > max_line_len {
			break
		}
	}
	return res.str()
}

fn (mut r Redis) read_reply() !string {
	mut pro := new_protocol(&r)
	return string(pro.read_reply()!.bytestr())
}

pub fn new_client(opts ConnOpts) !Redis {
	mut client := Redis{
		socket: net.dial_tcp('${opts.host}:${opts.port}')!
	}
	if opts.requirepass.len > 0 {
		if !client.send('AUTH "${opts.requirepass}"')!.starts_with(vredis.ok_flag) {
			return error('auth password failed')
		}
	}

	// if opts.name != '' && !client.send('CLIENT SETNAME "${opts.name}"')!.starts_with(vredis.ok_flag) {
	// 	return error('set client name failed')
	// }

	if opts.db > 0 && !client.send('SELECT ${opts.db}')!.starts_with(vredis.ok_flag) {
		return error('switch db failed')
	}
	return client
}

pub fn (mut r Redis) close() ! {
	r.@lock()
	defer {
		r.unlock()
	}
	r.socket.close()!
}

pub fn (mut r Redis) ping() !bool {
	return r.send('PING')! == 'PONG'
}

pub fn (mut r Redis) @type(key string) !string {
	return r.send('TYPE ${key}')!
}

[inline]
pub fn (mut r Redis) expire(key string, seconds int) !bool {
	return r.send('EXPIRE "${key}" ${seconds}')!.int() == 1
}

[inline]
pub fn (mut r Redis) pexpire(key string, millis int) !bool {
	return r.send('PEXPIRE "${key}" ${millis}')!.int() == 1
}

[inline]
pub fn (mut r Redis) expireat(key string, timestamp int) !bool {
	return r.send('EXPIREAT "${key}" ${timestamp}')!.int() == 1
}

[inline]
pub fn (mut r Redis) pexpireat(key string, millistimestamp i64) !bool {
	return r.send('PEXPIREAT "${key}" ${millistimestamp}')!.int() == 1
}

[inline]
pub fn (mut r Redis) persist(key string) !int {
	return r.send('PERSIST "${key}"')!.int()
}

[inline]
pub fn (mut r Redis) randomkey() !string {
	return r.send('RANDOMKEY')!
}

[inline]
pub fn (mut r Redis) ttl(key string) !int {
	return r.send('TTL "${key}"')!.int()
}

[inline]
pub fn (mut r Redis) pttl(key string) !int {
	return r.send('PTTL "${key}"')!.int()
}

[inline]
pub fn (mut r Redis) exists(key string) !bool {
	return r.send('EXISTS "${key}"')!.int() == 1
}

[inline]
pub fn (mut r Redis) del(key string) !bool {
	return r.send('DEL "${key}"')!.int() == 1
}

[inline]
pub fn (mut r Redis) rename(key string, newkey string) !bool {
	return r.send('RENAME "${key}" "${newkey}"')!.starts_with(vredis.ok_flag)
}

[inline]
pub fn (mut r Redis) renamenx(key string, newkey string) !bool {
	return r.send('RENAMENX "${key}" "${newkey}"')!.int() == 1
}

[inline]
pub fn (mut r Redis) flushall() !bool {
	return r.send('FLUSHALL')!.starts_with(vredis.ok_flag)
}
