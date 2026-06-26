module vredis

@[inline]
pub fn (mut r Redis) incrby(key string, increment int) !int {
	return r.send('INCRBY', key, increment)!.int()
}

@[inline]
pub fn (mut r Redis) incr(key string) !int {
	return r.incrby(key, 1)!
}

@[inline]
pub fn (mut r Redis) decr(key string) !int {
	return r.incrby(key, -1)!
}

@[inline]
pub fn (mut r Redis) decrby(key string, decrement int) !int {
	return r.incrby(key, -decrement)!
}

@[inline]
pub fn (mut r Redis) incrbyfloat(key string, increment f64) !f64 {
	return r.send('INCRBYFLOAT', key, increment)!.f64()
}

@[inline]
pub fn (mut r Redis) append(key string, value string) !int {
	return r.send('APPEND', key, value)!.int()
}

@[inline]
pub fn (mut r Redis) strlen(key string) !int {
	return r.send('STRLEN', key)!.int()
}

// get returns the string value stored at `key`. Returns err_nil when
// the key does not exist.
pub fn (mut r Redis) get(key string) !string {
	reply := r.send('GET', key)!
	if reply.kind == .nil_reply {
		return err_nil
	}
	return reply.bytestr()
}

// getset atomically sets `key` to `value` and returns the previous
// value. Returns err_nil when the key did not exist.
pub fn (mut r Redis) getset(key string, value string) !string {
	reply := r.send('GETSET', key, value)!
	if reply.kind == .nil_reply {
		return err_nil
	}
	return reply.bytestr()
}

@[inline]
pub fn (mut r Redis) getrange(key string, start int, end int) !string {
	return r.send('GETRANGE', key, start, end)!.bytestr()
}

pub fn (mut r Redis) setnx(key string, value string) !bool {
	return r.set_opts(key, value, SetOpts{
		nx: true
	})!
}

pub fn (mut r Redis) setrange(key string, offset int, value string) !int {
	return r.send('SETRANGE', key, offset, value)!.int()
}

pub fn (mut r Redis) setex(key string, seconds int, value string) !bool {
	return r.set_opts(key, value, SetOpts{
		ex: seconds
	})!
}

pub fn (mut r Redis) set(key string, value string) !bool {
	return r.send('SET', key, value)!.ok()
}

pub fn (mut r Redis) setbit(key string, offset int, value int) !int {
	return r.send('SETBIT', key, offset, value)!.int()
}

pub fn (mut r Redis) getbit(key string, offset int) !int {
	return r.send('GETBIT', key, offset)!.int()
}

// mget returns a map of key→value for the requested keys. Keys that do
// not exist are omitted from the map; callers can distinguish "missing"
// from "present with empty value" via `key in map`.
pub fn (mut r Redis) mget(key string, keys ...string) !map[string]string {
	mut args := [CmdArg(key)]
	for it in keys {
		args << it
	}

	mut data := map[string]string{}
	reply := r.send('MGET', ...args)!
	if reply.kind != .array {
		return data
	}
	for i, elem in reply.arr {
		if elem.kind == .nil_reply {
			continue
		}
		data[args[i] as string] = elem.str_val
	}
	return data
}

// set_opts issues a SET command with optional EX/PX/NX/XX/KEEPTTL flags.
//
// Bug fix: the previous implementation omitted `key` from the argument
// list, so every call sent `SET <value> [flags]` which either failed or
// set the wrong key.
pub fn (mut r Redis) set_opts(key string, value string, opts SetOpts) !bool {
	mut args := [CmdArg(key), CmdArg(value)]

	if opts.ex != -4 {
		args << 'EX'
		args << opts.ex
	} else if opts.px != -4 {
		args << 'PX'
		args << opts.px
	}

	if opts.nx {
		args << 'NX'
	} else if opts.xx {
		args << 'XX'
	}

	if opts.keep_ttl {
		args << 'KEEPTTL'
	}

	return r.send('SET', ...args)!.ok()
}

@[inline]
pub fn (mut r Redis) keys(pattern string) ![]string {
	return r.send('KEYS', pattern)!.strings()
}

pub fn (mut r Redis) psetex(key string, millis int, value string) !bool {
	return r.set_opts(key, value, SetOpts{
		px: millis
	})!
}
