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

fn (mut r Redis) send_cmd(cmd string) !string {
	r.@lock()
	defer {
		r.unlock()
	}
	r.socket.write_string(cmd + '\r\n')!
	mut line := r.socket.read_line()
	// if cmd.contains('HGETALL') {
	// 	println('HGETALL')
	// 	println('HGETALL: ${line}')
	// 	return line
	// }
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
			if line_cont.starts_with('$') {
				lines << r.read_from_socket(line_cont.trim_left('$').int() + 2)!.trim_right('\r\n')
			}
		}
		return lines.join('\r\n')
	}
	return line.trim_right('\r\n')
}

pub fn connect(opts ConnOpts) !Redis {
	mut client := Redis{
		socket: net.dial_tcp('${opts.host}:${opts.port}')!
	}

	if opts.requirepass.len > 0 {
		if !client.send_cmd('AUTH "${opts.requirepass}"')!.starts_with(ok_flag) {
			panic(error('auth password failed'))
		}
	}

	if opts.db > 0 && !client.send_cmd('SELECT ${opts.db}')!.starts_with(ok_flag) {
		panic(error('switch db failed'))
	}

	return client
}

pub fn (mut r Redis) ping() !bool {
	return r.send_cmd('PING')! == '+PONG'
}

pub fn (mut r Redis) close() ! {
	r.socket.close()!
}

pub fn (mut r Redis) set_opts(key string, value string, opts SetOpts) bool {
	ex := if opts.ex == -4 && opts.px == -4 {
		''
	} else if opts.ex != -4 {
		' EX ${opts.ex}'
	} else {
		' PX ${opts.px}'
	}
	nx := if opts.nx == false && opts.xx == false {
		''
	} else if opts.nx == true {
		' NX'
	} else {
		' XX'
	}
	keep_ttl := if opts.keep_ttl == false { '' } else { ' KEEPTTL' }
	res := r.send_cmd('SET "${key}" "${value}"${ex}${nx}${keep_ttl}') or { return false }
	return res.starts_with(ok_flag)
}

pub fn (mut r Redis) psetex(key string, millis int, value string) bool {
	return r.set_opts(key, value, SetOpts{
		px: millis
	})
}

pub fn (mut r Redis) expire(key string, seconds int) !int {
	res := r.send_cmd('EXPIRE "${key}" ${seconds}')!
	return res.int()
}

pub fn (mut r Redis) pexpire(key string, millis int) !int {
	res := r.send_cmd('PEXPIRE "${key}" ${millis}')!
	return res.int()
}

pub fn (mut r Redis) expireat(key string, timestamp int) !int {
	res := r.send_cmd('EXPIREAT "${key}" ${timestamp}')!
	return res.int()
}

pub fn (mut r Redis) pexpireat(key string, millistimestamp i64) !int {
	res := r.send_cmd('PEXPIREAT "${key}" ${millistimestamp}')!
	return res.int()
}

pub fn (mut r Redis) persist(key string) !int {
	res := r.send_cmd('PERSIST "${key}"')!
	return res.int()
}

pub fn (mut r Redis) randomkey() !string {
	res := r.send_cmd('RANDOMKEY')!
	len := res.int()
	if len == -1 {
		return error('database is empty')
	}
	return r.socket.read_line()[0..len]
}

pub fn (mut r Redis) ttl(key string) !int {
	res := r.send_cmd('TTL "${key}"')!
	return res.int()
}

pub fn (mut r Redis) pttl(key string) !int {
	res := r.send_cmd('PTTL "${key}"')!
	return res.int()
}

pub fn (mut r Redis) exists(key string) !int {
	res := r.send_cmd('EXISTS "${key}"')!
	return res.int()
}

pub fn (mut r Redis) type_of(key string) !KeyType {
	res := r.send_cmd('TYPE "${key}"')!
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
	res := r.send_cmd('DEL "${key}"')!
	return res.int()
}

pub fn (mut r Redis) rename(key string, newkey string) bool {
	res := r.send_cmd('RENAME "${key}" "${newkey}"') or { return false }
	return res.starts_with(ok_flag)
}

pub fn (mut r Redis) renamenx(key string, newkey string) !int {
	res := r.send_cmd('RENAMENX "${key}" "${newkey}"')!
	rerr := parse_err(res)
	if rerr != '' {
		return error(rerr)
	}
	return res.int()
}

pub fn (mut r Redis) flushall() bool {
	res := r.send_cmd('FLUSHALL') or { return false }
	return res.starts_with(ok_flag)
}

fn parse_err(res string) string {
	if res.len >= 5 && res.starts_with('-ERR') {
		return res[5..res.len - 2]
	} else if res.len >= 11 && res[0..10] == '-WRONGTYPE' {
		return res[11..res.len - 2]
	}
	return ''
}
