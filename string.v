module vredis

[inline]
pub fn (mut r Redis) incrby(key string, increment int) !int {
	res := r.send('INCRBY "${key}" ${increment}')!
	r.check_err(res)!
	return r.to_num_str(res).int()
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

pub fn (mut r Redis) incrbyfloat(key string, increment f64) !f64 {
	mut res := r.send('INCRBYFLOAT "${key}" ${increment}')!
	r.check_err(res)!
	res = r.socket.read_line()
	return res.f64()
}

[inline]
pub fn (mut r Redis) append(key string, value string) !int {
	return r.send('APPEND "${key}" "${value}"')!.int()
}

[inline]
pub fn (mut r Redis) strlen(key string) !int {
	return r.send('STRLEN "${key}"')!.int()
}

[inline]
pub fn (mut r Redis) get(key string) !string {
	return r.check_err(r.send('GET "${key}"')!)!
}

[inline]
pub fn (mut r Redis) getset(key string, value string) !string {
	return r.check_err(r.send('GETSET "${key}" ${value}')!)!
}

pub fn (mut r Redis) getrange(key string, start int, end int) !string {
	res := r.send('GETRANGE "${key}" ${start} ${end}')!
	len := res.int()
	if len == 0 {
		r.socket.read_line()
		return ''
	}
	return r.socket.read_line()[0..len]
}

pub fn (mut r Redis) setnx(key string, value string) int {
	res := r.set_opts(key, value, SetOpts{
		nx: true
	})
	return if res == true { 1 } else { 0 }
}

pub fn (mut r Redis) setrange(key string, offset int, value string) !int {
	res := r.send('SETRANGE "${key}" ${offset} "${value}"')!
	return res.int()
}

pub fn (mut r Redis) setex(key string, seconds int, value string) bool {
	return r.set_opts(key, value, SetOpts{
		ex: seconds
	})
}

pub fn (mut r Redis) set(key string, value string) bool {
	res := r.send('SET "${key}" "${value}"') or { return false }
	return res.starts_with(ok_flag)
}

pub fn (mut r Redis) setbit(key string, offset int, value u8) bool {
	res := r.send('SETBIT "${key}" ${offset} ${value}') or { return false }
	return res in [':0', ':1']
}

pub fn (mut r Redis) getbit(key string, offset int) u8 {
	res := r.send('GETBIT "${key}" ${offset}') or { return 0 }
	return res.trim_left(':').u8()
}

pub fn (mut r Redis) mget(key string, keys ...string) map[string]string {
	mut keyarr := [key]
	keyarr << keys

	mut data := map[string]string{}
	res := r.send('MGET ${keyarr.join(' ')}') or { return data }
	vals := res.split('\r\n')

	for i := 0; i < keyarr.len; i++ {
		data[keyarr[i]] = vals[i]
	}
	return data
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
	res := r.send('SET "${key}" "${value}"${ex}${nx}${keep_ttl}') or { return false }
	return res.starts_with(ok_flag)
}

pub fn (mut r Redis) psetex(key string, millis int, value string) bool {
	return r.set_opts(key, value, SetOpts{
		px: millis
	})
}
