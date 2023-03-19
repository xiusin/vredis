module vredis

import net
import time
import sync
import strings

[params]
pub struct ConnOpts {
	read_timeout  time.Duration
	write_timeout time.Duration
	port          int    = 6379
	host          string = '127.0.0.1'
	username      string
	requirepass   string
	db            int
}

const ok_flag = '+OK'

pub struct Redis {
	sync.Mutex
mut:
	socket &net.TcpConn = unsafe { nil }
	prev_cmd string
}

pub struct SetOpts {
	ex       int = -4
	px       int = -4
	nx       bool
	xx       bool
	keep_ttl bool
}

pub enum KeyType {
	t_none
	t_string
	t_list
	t_set
	t_zset
	t_hash
	t_stream
	t_unknown
}

fn (mut r Redis) str() string {
	return r'vredis.Redis{}'
}

fn (mut r Redis) read_from_socket(len int) !string {
	mut read_cnt := 0
	mut s_buf := strings.new_builder(len)
	for read_cnt != len {
		// After multiple tests, it has been found that there may be a situation where the content is not fully read at once, so segmented reading is temporarily being used.取
		chunk_len := if len - read_cnt >= 1024 { 1024 } else { len - read_cnt }
		mut buf := []u8{len: chunk_len}
		read_chunk_cnt := r.socket.read(mut buf)!
		read_cnt += read_chunk_cnt
		s_buf.write(buf[0..read_chunk_cnt])!
		unsafe { buf.free() }
	}
	str := s_buf.bytestr()
	unsafe { s_buf.free() }
	return str
}

pub fn (mut r Redis) send(cmd string) !string {
	r.@lock()
	defer {
		r.unlock()
	}
	r.write_string_to_socket(cmd)!
	return r.read_reply()!
}

pub fn(mut r Redis) write_string_to_socket(cmd string)! {
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


fn (mut r Redis) read_reply(no_blocking... bool) !string {
	mut line := ""
	if no_blocking.len  == 0 || no_blocking[0] == false {
		line = r.socket.read_line()
	} else {
		line = r.read_no_block(net.max_read_line_len)
	}
	println('${r.prev_cmd} => ${line}')
	if line.starts_with('$') {
		return if line.starts_with('$-1') {
			'(nil)'
		} else {
			r.read_from_socket(line.trim_left('$').int() + 2)!
		}
	} else if line.starts_with('*') {
		line_num := line.trim_left('*').int()
		mut lines := []string{cap: line_num}
		for i := 0; i < line_num; i++ {
			line_cont := r.socket.read_line()
			if line_cont.contains('$-1') {
				lines << '(nil)' // mget
			} else if line_cont.starts_with('$') {
				lines << r.read_from_socket(line_cont.trim_left('$').int() + 2)!.trim_right('\r\n')
			} else if line_cont.starts_with(':') {
				lines << line_cont[1..].trim_right('\r\n')
			} else if line_cont.starts_with('*') {
				lines << line_cont.trim_right('\r\n')
			}
		}
		return lines.join('\r\n')
	}
	return line.trim_right('\r\n')
}

pub fn new_client(opts ConnOpts) !Redis {
	mut client := Redis{
		socket: net.dial_tcp('${opts.host}:${opts.port}')!
	}

	if opts.requirepass.len > 0 {
		if !client.send('AUTH "${opts.requirepass}"')!.starts_with(ok_flag) {
			panic(error('auth password failed'))
		}
	}

	if opts.db > 0 && !client.send('SELECT ${opts.db}')!.starts_with(ok_flag) {
		panic(error('switch db failed'))
	}
	return client
}

pub fn (mut r Redis) ping() !bool {
	return r.send('PING')! == '+PONG'
}

pub fn (mut r Redis) close() ! {
	r.socket.close()!
}

pub fn (mut r Redis) expire(key string, seconds int) !int {
	res := r.send('EXPIRE "${key}" ${seconds}')!
	return res.int()
}

pub fn (mut r Redis) pexpire(key string, millis int) !int {
	res := r.send('PEXPIRE "${key}" ${millis}')!
	return res.int()
}

pub fn (mut r Redis) expireat(key string, timestamp int) !int {
	res := r.send('EXPIREAT "${key}" ${timestamp}')!
	return res.int()
}

pub fn (mut r Redis) pexpireat(key string, millistimestamp i64) !int {
	res := r.send('PEXPIREAT "${key}" ${millistimestamp}')!
	return res.int()
}

pub fn (mut r Redis) persist(key string) !int {
	res := r.send('PERSIST "${key}"')!
	return res.int()
}

pub fn (mut r Redis) randomkey() !string {
	return r.send('RANDOMKEY')!
}

pub fn (mut r Redis) ttl(key string) !int {
	res := r.send('TTL "${key}"')!
	return res.int()
}

pub fn (mut r Redis) pttl(key string) !int {
	res := r.send('PTTL "${key}"')!
	return res.int()
}

pub fn (mut r Redis) exists(key string) !int {
	res := r.send('EXISTS "${key}"')!
	return res.int()
}

pub fn (mut r Redis) type_of(key string) !KeyType {
	res := r.send('TYPE "${key}"')!
	if res.len > 6 {
		return match res#[1..res.len - 2] {
			'none' {
				KeyType.t_none
			}
			'string' {
				KeyType.t_string
			}
			'list' {
				KeyType.t_list
			}
			'set' {
				KeyType.t_set
			}
			'zset' {
				KeyType.t_zset
			}
			'hash' {
				KeyType.t_hash
			}
			'stream' {
				KeyType.t_stream
			}
			else {
				KeyType.t_unknown
			}
		}
	} else {
		return KeyType.t_unknown
	}
}

pub fn (mut r Redis) del(key string) !int {
	res := r.send('DEL "${key}"')!
	return res.int()
}

pub fn (mut r Redis) rename(key string, newkey string) bool {
	res := r.send('RENAME "${key}" "${newkey}"') or { return false }
	return res.starts_with(ok_flag)
}

pub fn (mut r Redis) renamenx(key string, newkey string) !int {
	res := r.send('RENAMENX "${key}" "${newkey}"')!
	r.check_err(res)!
	return res.int()
}

pub fn (mut r Redis) flushall() bool {
	res := r.send('FLUSHALL') or { return false }
	return res.starts_with(ok_flag)
}

fn (mut r Redis) check_err(res string) ! {
	if res.len >= 5 && res.starts_with('-') {
		return error(res[1..].trim_right('\r\n'))
	} else if res.len >= 11 && res[0..10] == '-WRONGTYPE' {
		return error(res[11..res.len - 2])
	}
	return
}
