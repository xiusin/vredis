module vredis

[inline]
pub fn (mut r Redis) incrby(key string, increment int) !int {
	return r.send('INCRBY', key, increment)!.int()
}

[inline]
pub fn (mut r Redis) incr(key string) !int {
	return r.incrby(key, 1)!
}

[inline]
pub fn (mut r Redis) decr(key string) !int {
	return r.incrby(key, -1)!
}

[inline]
pub fn (mut r Redis) decrby(key string, decrement int) !int {
	return r.incrby(key, -decrement)!
}

[inline]
pub fn (mut r Redis) incrbyfloat(key string, increment f64) !f64 {
	return r.send('INCRBYFLOAT', key, increment)!.f64()
}

[inline]
pub fn (mut r Redis) append(key string, value string) !int {
	return r.send('APPEND', key, value)!.int()
}

[inline]
pub fn (mut r Redis) strlen(key string) !int {
	return r.send('STRLEN', key)!.int()
}

[inline]
pub fn (mut r Redis) get(key string) !string {
	return r.send('GET', key)!
}

[inline]
pub fn (mut r Redis) getset(key string, value string) !string {
	return r.send('GETSET', key, value)!
}

[inline]
pub fn (mut r Redis) getrange(key string, start int, end int) !string {
	return r.send('GETRANGE', key, start, end)!
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
	return r.send('SET', key, value)!.starts_with(ok_flag)
}

pub fn (mut r Redis) setbit(key string, offset int, value int) !bool {
	ret := r.send('SETBIT', key, offset, value)!
	return ret  in ['0', '1']
}

pub fn (mut r Redis) getbit(key string, offset int) int {
	res := r.send('GETBIT', key, offset) or { return 0 }
	return res.int()
}

pub fn (mut r Redis) mget(key string, keys ...string) !map[string]string {
	mut args := [CmdArg(key)]
	for it in keys {
		args << it
	}

	mut data := map[string]string{}
	res := r.send('MGET', ...args)!
	vals := res.split('\r\n')

	for i := 0; i < args.len; i++ {
		data[args[i] as string] = vals[i]
	}
	return data
}

pub fn (mut r Redis) set_opts(key string, value string, opts SetOpts) !bool {
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

	mut args := [CmdArg(value)]
	args << ex
	args << nx
	args << keep_ttl

	res := r.send('SET', ...args) or { return false }
	return res.starts_with(ok_flag)
}

[inline]
pub fn (mut r Redis) keys(pattern string) ![]string {
	return r.send('KEYS', pattern)!.split('\r\n')
}

pub fn (mut r Redis) psetex(key string, millis int, value string) !bool {
	return r.set_opts(key, value, SetOpts{
		px: millis
	})
}
