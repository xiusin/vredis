module vredis

import net
import sync
import time

// err_nil is returned by helpers that explicitly need to signal "no value".
pub const err_nil = error('redis: nil reply')

// ConnOpts configures a new Redis client connection. All fields have
// sensible defaults so callers can use `new_client()` for a localhost
// connection on the default port.
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

// Redis is a single, thread-safe connection to a Redis server.
//
// Concurrency model: a sync.Mutex serialises command send/recv pairs so
// that a reply is always matched to the command that produced it. Callers
// that need parallelism should use a Pool.
pub struct Redis {
	sync.Mutex
mut:
	is_active bool         = true
	socket    &net.TcpConn = unsafe { nil }
	prev_cmd  string
	debug     bool
	protocol  &Protocol = unsafe { nil }
}

// SetOpts carries the optional flags accepted by the SET command.
// The sentinel -4 means "unset"; it is chosen to be distinct from any
// legitimate expiry value (which must be positive).
pub struct SetOpts {
	ex       int = -4
	px       int = -4
	nx       bool
	xx       bool
	keep_ttl bool
}

// set_debug enables printing of the raw RESP traffic to stdout.
pub fn (mut r Redis) set_debug(debug bool) {
	r.debug = debug
}

fn (r &Redis) str() string {
	return 'Redis{prev_cmd: "${r.prev_cmd}"}'
}

// send serialises a command + arguments, writes them to the socket,
// and returns the parsed Reply.
//
// The mutex guarantees that a reply is always paired with the command
// that produced it, even when multiple goroutines share the same
// connection (though a Pool is the recommended way to parallelise).
pub fn (mut r Redis) send(cmd string, params ...CmdArg) !&Reply {
	r.@lock()
	defer {
		r.unlock()
	}

	if !r.is_active {
		return err_conn_no_active
	}

	// Build the argument list with a single allocation.
	mut args := []CmdArg{cap: 1 + params.len}
	args << CmdArg(cmd)
	args << params

	// Wrap in CmdArgs so we can use the RESP serialiser.
	mut cmd_args := CmdArgs(args)
	r.write_cmd(cmd_args.build())!

	reply := r.protocol.read_reply()!
	return &reply
}

// write_cmd writes a pre-serialised RESP command to the socket. It is
// kept public so that pub/sub code can reuse the same write path
// without going through the locked send() method.
pub fn (mut r Redis) write_cmd(cmd string) ! {
	r.prev_cmd = cmd
	if r.debug {
		println('-> ${cmd}')
	}
	r.socket.write_string(cmd)!
}

// write_string_to_socket is retained for backwards compatibility with
// callers that build their own command strings.
@[deprecated: 'use write_cmd instead']
pub fn (mut r Redis) write_string_to_socket(cmd string) ! {
	r.write_cmd(cmd)!
}

// new_client dials a Redis server, applies timeouts, authenticates,
// optionally sets a client name, and selects the requested database.
//
// On any configuration failure the underlying socket is closed so that
// no file descriptor is leaked.
pub fn new_client(opts ConnOpts) !&Redis {
	mut client := &Redis{
		socket: net.dial_tcp('${opts.host}:${opts.port}')!
	}
	client.protocol = new_protocol(client)

	if opts.read_timeout > 0 {
		client.socket.set_read_timeout(opts.read_timeout)
	}
	if opts.write_timeout > 0 {
		client.socket.set_write_timeout(opts.write_timeout)
	}

	// Authentication — Redis 6+ supports AUTH with username + password.
	if opts.requirepass.len > 0 {
		auth_ok := if opts.username.len > 0 {
			client.send('AUTH', opts.username, opts.requirepass)!.ok()
		} else {
			client.send('AUTH', opts.requirepass)!.ok()
		}
		if !auth_ok {
			client.socket.close() or {}
			return error('redis: auth failed')
		}
	}

	// Optional CLIENT SETNAME.
	if opts.name != '' {
		if !client.send('CLIENT', 'SETNAME', opts.name)!.ok() {
			client.socket.close() or {}
			return error('redis: set client name failed')
		}
	}

	// SELECT database.
	if !client.@select(opts.db) or { false } {
		client.socket.close() or {}
		return error('redis: select db failed')
	}

	return client
}

// close sends QUIT and closes the underlying socket. It is safe to
// call multiple times.
pub fn (mut r Redis) close() ! {
	r.@lock()
	defer {
		r.unlock()
	}
	if !r.is_active {
		return
	}
	r.is_active = false

	// Best-effort QUIT; ignore write errors on a broken connection.
	if r.debug {
		println('-> QUIT')
	}
	r.socket.write_string('QUIT\r\n') or {}
	r.socket.close() or {}
}

// ---------------------------------------------------------------------------
// Inline command wrappers — each maps 1:1 to a Redis command.
// ---------------------------------------------------------------------------

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

// scan iterates the key space using the cursor-based SCAN command.
// The reply is a two-element array: [cursor, [keys...]].
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

	reply := r.send('SCAN', ...args)!
	return parse_scan_reply(reply)
}

// parse_scan_reply extracts the cursor and key list from a SCAN/SSCAN/ZSCAN
// reply. The reply is always a 2-element array: [cursor-bulk, keys-array].
// Centralising this logic avoids duplication across scan/sscan/zscan.
@[inline]
fn parse_scan_reply(reply &Reply) !ScanReply {
	if reply.kind != .array || reply.arr.len < 2 {
		return error('redis: invalid scan reply')
	}
	cursor_str := reply.arr[0].str_val
	mut result := []string{}
	if reply.arr[1].kind == .array {
		result = []string{cap: reply.arr[1].arr.len}
		for elem in reply.arr[1].arr {
			result << elem.str_val
		}
	}
	return ScanReply{
		cursor: cursor_str.u64()
		result: result
	}
}
