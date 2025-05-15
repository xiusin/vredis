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

@[inline]
pub fn (mut r Redis) get(key string) !string {
	return r.send('GET', key)!.bytestr()
}

@[inline]
pub fn (mut r Redis) getset(key string, value string) !string {
	return r.send('GETSET', key, value)!.bytestr()
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

pub fn (mut r Redis) setbit(key string, offset int, value int) !bool {
	return r.send('SETBIT', key, offset, value)!.@is(1)
}

pub fn (mut r Redis) getbit(key string, offset int) !int {
	return r.send('GETBIT', key, offset)!.int()
}

pub fn (mut r Redis) mget(key string, keys ...string) !map[string]string {
	mut args := [CmdArg(key)]
	for it in keys {
		args << it
	}

	mut data := map[string]string{}
	vals := r.send('MGET', ...args)!.strings()

	for i := 0; i < args.len; i++ {
		data[args[i] as string] = vals[i]
	}
	return data
}

pub fn (mut r Redis) set_opts(key string, value string, opts SetOpts) !bool {
	mut args := [CmdArg(value)]
	if opts.ex == -4 && opts.px == -4 {
	} else if opts.ex != -4 {
		args << 'EX'
		args << '${opts.ex}'
	} else {
		args << 'PX'
		args << '${opts.px}'
	}
	 if opts.nx == false && opts.xx == false {
	} else if opts.nx == true {
		args << 'NX'
	} else {
		args << 'XX'
	}
	if opts.keep_ttl  {
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
	})
}
