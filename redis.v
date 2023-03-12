module vredis

import net
import time
import sync

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

fn (mut r Redis) send_cmd(cmd string) !string {
	r.@lock()
	defer {
		r.unlock()
	}
	println('${cmd} line')
	r.socket.write_string(cmd + '\r\n')!
	mut line := r.socket.read_line()
	println('-----> ' + line)
	// println('${cmd} line: ${line}')
	if line.starts_with('$') {
		mut buf := []u8{len: line.trim_left('$').int() - line.len}
		r.socket.read(mut buf)!
		return buf.bytestr()
	}
	return line
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

	if opts.db > 0 && !client.send_cmd('SELECT ${opts.db}')!.starts_with(ok_flag){
		panic(error('switch db failed'))
	}
	// spawn fn [mut client] ()! {
	// 	for {
	// 		println(client.send_cmd('PING')!)
	// 		time.sleep(time.second * 1)
	// 	}
	// }()

	return client
}


pub fn (mut r Redis) disconnect() {
	r.socket.close() or {}
}

pub fn (mut r Redis) set(key string, value string) bool {
	res := r.send_cmd('SET "${key}" "${value}"') or { return false }
	return res.starts_with(ok_flag)
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

pub fn (mut r Redis) setex(key string, seconds int, value string) bool {
	return r.set_opts(key, value, SetOpts{
		ex: seconds
	})
}

pub fn (mut r Redis) psetex(key string, millis int, value string) bool {
	return r.set_opts(key, value, SetOpts{
		px: millis
	})
}

pub fn (mut r Redis) setnx(key string, value string) int {
	res := r.set_opts(key, value, SetOpts{
		nx: true
	})
	return if res == true { 1 } else { 0 }
}

pub fn (mut r Redis) incrby(key string, increment int) !int {
	res := r.send_cmd('INCRBY "${key}" ${increment}')!
	rerr := parse_err(res)
	if rerr != '' {
		return error(rerr)
	}
	return res.int()
}

pub fn (mut r Redis) incr(key string) !int {
	res := r.incrby(key, 1)!
	return res
}

pub fn (mut r Redis) decr(key string) !int {
	res := r.incrby(key, -1)!
	return res
}

pub fn (mut r Redis) decrby(key string, decrement int) !int {
	res := r.incrby(key, -decrement)!
	return res
}

pub fn (mut r Redis) incrbyfloat(key string, increment f64) !f64 {
	mut res := r.send_cmd('INCRBYFLOAT "${key}" ${increment}')!
	rerr := parse_err(res)
	if rerr != '' {
		return error(rerr)
	}
	res = r.socket.read_line()
	return res.f64()
}

pub fn (mut r Redis) append(key string, value string) !int {
	res := r.send_cmd('APPEND "${key}" "${value}"')!
	return res.int()
}

pub fn (mut r Redis) setrange(key string, offset int, value string) !int {
	res := r.send_cmd('SETRANGE "${key}" ${offset} "${value}"')!
	return res.int()
}

pub fn (mut r Redis) lpush(key string, element string) !int {
	res := r.send_cmd('LPUSH "${key}" "${element}"')!
	return res.int()
}

pub fn (mut r Redis) rpush(key string, element string) !int {
	res := r.send_cmd('RPUSH "${key}" "${element}"')!
	return res.int()
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

pub fn (mut r Redis) get(key string) !string {
	res := r.send_cmd('GET "${key}"')!
	len := res.int()
	if len == -1 {
		return error('key not found')
	}
	return r.socket.read_line()[0..len]
}

pub fn (mut r Redis) getset(key string, value string) !string {
	res := r.send_cmd('GETSET "${key}" ${value}')!
	len := res.int()
	if len == -1 {
		return ''
	}
	return r.socket.read_line()[0..len]
}

pub fn (mut r Redis) getrange(key string, start int, end int) !string {
	res := r.send_cmd('GETRANGE "${key}" ${start} ${end}')!
	len := res.int()
	if len == 0 {
		r.socket.read_line()
		return ''
	}
	return r.socket.read_line()[0..len]
}

pub fn (mut r Redis) randomkey() !string {
	res := r.send_cmd('RANDOMKEY')!
	len := res.int()
	if len == -1 {
		return error('database is empty')
	}
	return r.socket.read_line()[0..len]
}

pub fn (mut r Redis) strlen(key string) !int {
	res := r.send_cmd('STRLEN "${key}"')!
	return res.int()
}

pub fn (mut r Redis) lpop(key string) !string {
	res := r.send_cmd('LPOP "${key}"')!
	len := res.int()
	if len == -1 {
		return error('key not found')
	}
	return r.socket.read_line()[0..len]
}

pub fn (mut r Redis) rpop(key string) !string {
	res := r.send_cmd('RPOP "${key}"')!
	len := res.int()
	if len == -1 {
		return error('key not found')
	}
	return r.socket.read_line()[0..len]
}

pub fn (mut r Redis) llen(key string) !int {
	res := r.send_cmd('LLEN "${key}"')!
	rerr := parse_err(res)
	if rerr != '' {
		return error(rerr)
	}
	return res.int()
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
