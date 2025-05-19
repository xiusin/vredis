module vredis

import net
import time
import sync

const err_nil = error('redis get nil')

@[params]
pub struct ConnOpts {
pub:
	read_timeout  time.Duration = time.second * 10
	write_timeout time.Duration = time.second * 10
	name          string
	port          int = 6379
	db            u32
	host          string = '127.0.0.1'
	username      string
	requirepass   string
}

pub struct Redis {
	sync.Mutex
mut:
	is_active bool         = true
	socket    &net.TcpConn = unsafe { nil }
	prev_cmd  string
	debug     bool
	protocol  &Protocol = unsafe { nil }
}

pub struct SetOpts {
	ex       int = -4
	px       int = -4
	nx       bool
	xx       bool
	keep_ttl bool
}

pub fn (mut r Redis) set_debug(debug bool) {
	r.debug = debug
}

fn (mut r Redis) str() string {
	return '&vredis.Redis{
	prev_cmd: ${r.prev_cmd}
}'
}

pub fn (mut r Redis) send(cmd string, params ...CmdArg) !&Reply {
	r.@lock()
	defer {
		r.unlock()
	}

	if !r.is_active {
		return err_conn_no_active
	}

	mut args := CmdArgs([]CmdArg{})
	args.add(CmdArg(cmd))
	args.add(...params)
	r.write_string_to_socket(args.build())!

	reply := &Reply{
		data: r.protocol.read_reply()!
	}

	if reply.data.bytestr() == nil_flag {
		return err_nil
	}

	return reply
}

pub fn (mut r Redis) write_string_to_socket(cmd string) ! {
	r.prev_cmd = cmd
	if r.debug {
		println('-> ${cmd}')
	}
	r.socket.write_string(cmd)!
}

pub fn new_client(opts ConnOpts) !&Redis {
	mut client := &Redis{
		socket: net.dial_tcp('${opts.host}:${opts.port}')!
	}

	if opts.read_timeout > 0 {
		client.socket.set_read_timeout(opts.read_timeout)
	}

	if opts.write_timeout > 0 {
		client.socket.set_write_timeout(opts.write_timeout)
	}

	client.protocol = new_protocol(client)

	if opts.requirepass.len > 0 {
		if !client.send('AUTH', opts.requirepass)!.ok() {
			return error('auth password failed')
		}
	}

	if opts.name != '' {
		if !client.send('CLIENT', 'SETNAME', opts.name)!.ok() {
			return error('set client name failed')
		}
	}

	if !client.@select(opts.db) or { false } {
		return error('client select db failed')
	}

	return client
}

pub fn (mut r Redis) close() ! {
	r.send('QUIT')!

	r.@lock()
	defer {
		r.unlock()
	}
	r.socket.close()!
}

@[inline]
pub fn (mut r Redis) ping() !bool {
	return r.send('PING')!.@is('PONG')
}

@[inline]
pub fn (mut r Redis) @type(key string) !string {
	return r.send('TYPE', key)!.bytestr()
}

@[inline]
pub fn (mut r Redis) expire(key string, seconds int) !bool {
	return r.send('EXPIRE', key, seconds)!.@is(1)
}

@[inline]
pub fn (mut r Redis) pexpire(key string, millis int) !bool {
	return r.send('PEXPIRE', key, millis)!.@is(1)
}

@[inline]
pub fn (mut r Redis) expireat(key string, timestamp int) !bool {
	return r.send('EXPIREAT', key, timestamp)!.@is(1)
}

@[inline]
pub fn (mut r Redis) pexpireat(key string, millistimestamp int) !bool {
	return r.send('PEXPIREAT', key, millistimestamp)!.@is(1)
}

@[inline]
pub fn (mut r Redis) persist(key string) !int {
	return r.send('PERSIST', key)!.int()
}

@[inline]
pub fn (mut r Redis) randomkey() !string {
	return r.send('RANDOMKEY')!.bytestr()
}

@[inline]
pub fn (mut r Redis) ttl(key string) !int {
	return r.send('TTL', key)!.int()
}

@[inline]
pub fn (mut r Redis) pttl(key string) !int {
	return r.send('PTTL', key)!.int()
}

@[inline]
pub fn (mut r Redis) exists(key string) !bool {
	return r.send('EXISTS', key)!.@is(1)
}

@[inline]
pub fn (mut r Redis) del(key string) !bool {
	return r.send('DEL', key)!.@is(1)
}

@[inline]
pub fn (mut r Redis) unlink(key string) !bool {
	return r.send('UNLINK', key)!.@is(1)
}

@[inline]
pub fn (mut r Redis) rename(key string, newkey string) !bool {
	return r.send('RENAME', key, newkey)!.ok()
}

@[inline]
pub fn (mut r Redis) renamenx(key string, newkey string) !bool {
	return r.send('RENAMENX', key, newkey)!.@is(1)
}

@[inline]
pub fn (mut r Redis) flushall() !bool {
	return r.send('FLUSHALL')!.ok()
}

@[inline]
pub fn (mut r Redis) flushdb() !bool {
	return r.send('FLUSHDB')!.ok()
}

@[inline]
pub fn (mut r Redis) @select(db u32) !bool {
	return r.send('SELECT', int(db))!.ok()
}

@[inline]
pub fn (mut r Redis) dbsize() !int {
	return r.send('DBSIZE')!.int()
}

@[inline]
pub fn (mut r Redis) move(key string, db u32) !bool {
	return r.send('MOVE', key, int(db))!.ok()
}

pub fn (mut r Redis) scan(opts ScanOpts) !ScanReply {
	mut args := [CmdArg(opts.cursor)]

	if opts.pattern.len > 0 {
		args << 'MATCH'
		args << opts.pattern
	}
	if opts.count > 0 {
		args << 'COUNT'
		args << opts.count
	}

	next_cursor, members := r.send('SCAN', ...args)!.data().bytestr().split_once(crlf) or {
		return error('error msg')
	}

	return ScanReply{
		cursor: next_cursor.u64()
		result: members.split(crlf)
	}
}
