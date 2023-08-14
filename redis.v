module vredis

import net
import time
import sync

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

pub struct Redis {
	sync.Mutex
mut:
	socket      &net.TcpConn = unsafe { nil }
	prev_cmd    string
	debug       bool
	protocol    &Protocol = unsafe { nil }
	pub_sub_chan chan string
}

pub struct SetOpts {
	ex       int = -4
	px       int = -4
	nx       bool
	xx       bool
	keep_ttl bool
}

fn (mut r Redis) str() string {
	return '&vredis.Redis{
	prev_cmd: ${r.prev_cmd}
}'
}

pub fn (mut r Redis) send(cmd string, params ...CmdArg) !string {
	r.@lock()
	defer {
		r.unlock()
	}

	mut args := CmdArgs([]CmdArg{})
	args.add(CmdArg(cmd))
	args.add(...params)
	r.write_string_to_socket(args.build())!
	return r.read_reply()!
}

pub fn (mut r Redis) write_string_to_socket(cmd string) ! {
	r.prev_cmd = cmd
	println('-> ${cmd}')
	r.socket.write_string(cmd)!
}

fn (mut r Redis) read_reply() !string {
	return string(r.protocol.read_reply()!.bytestr())
}

pub fn new_client(opts ConnOpts) !Redis {
	mut client := Redis{
		socket: net.dial_tcp('${opts.host}:${opts.port}')!
	}

	client.protocol = new_protocol(&client)

	if opts.requirepass.len > 0 {
		if !client.send('AUTH', opts.requirepass)!.starts_with(vredis.ok_flag) {
			return error('auth password failed')
		}
	}

	if opts.name != '' {
		if !client.send('CLIENT', 'SETNAME', opts.name)!.starts_with(vredis.ok_flag) {
			return error('set client name failed')
		}
	}

	if opts.db > 0 {
		if !client.send('SELECT', opts.db)!.starts_with(vredis.ok_flag) {
			return error('switch db failed')
		}
	}

	client.pub_sub_chan = chan string{}
	return client
}

pub fn (mut r Redis) close() ! {
	r.@lock()
	defer {
		r.unlock()
	}
	r.pub_sub_chan.close()
	r.socket.close()!
}

[inline]
pub fn (mut r Redis) ping() !bool {
	return r.send('PING')! == 'PONG'
}

[inline]
pub fn (mut r Redis) @type(key string) !string {
	return r.send('TYPE', key)!
}

[inline]
pub fn (mut r Redis) expire(key string, seconds int) !bool {
	return r.send('EXPIRE', key, seconds)!.int() == 1
}

[inline]
pub fn (mut r Redis) pexpire(key string, millis int) !bool {
	return r.send('PEXPIRE', key, millis)!.int() == 1
}

[inline]
pub fn (mut r Redis) expireat(key string, timestamp int) !bool {
	return r.send('EXPIREAT', key, timestamp)!.int() == 1
}

[inline]
pub fn (mut r Redis) pexpireat(key string, millistimestamp int) !bool {
	return r.send('PEXPIREAT', key, millistimestamp)!.int() == 1
}

[inline]
pub fn (mut r Redis) persist(key string) !int {
	return r.send('PERSIST', key)!.int()
}

[inline]
pub fn (mut r Redis) randomkey() !string {
	return r.send('RANDOMKEY')!
}

[inline]
pub fn (mut r Redis) ttl(key string) !int {
	return r.send('TTL', key)!.int()
}

[inline]
pub fn (mut r Redis) pttl(key string) !int {
	return r.send('PTTL', key)!.int()
}

[inline]
pub fn (mut r Redis) exists(key string) !bool {
	return r.send('EXISTS', key)!.int() == 1
}

[inline]
pub fn (mut r Redis) del(key string) !bool {
	return r.send('DEL', key)!.int() == 1
}

[inline]
pub fn (mut r Redis) unlink(key string) !bool {
	return r.send('UNLINK', key)!.int() == 1
}

[inline]
pub fn (mut r Redis) rename(key string, newkey string) !bool {
	return r.send('RENAME', key, newkey)!.starts_with(vredis.ok_flag)
}

[inline]
pub fn (mut r Redis) renamenx(key string, newkey string) !bool {
	return r.send('RENAMENX', key, newkey)!.int() == 1
}

[inline]
pub fn (mut r Redis) flushall() !bool {
	return r.send('FLUSHALL')!.starts_with(vredis.ok_flag)
}
