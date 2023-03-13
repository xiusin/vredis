module vredis

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

pub fn (mut r Redis) strlen(key string) !int {
	res := r.send_cmd('STRLEN "${key}"')!
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

pub fn (mut r Redis) setnx(key string, value string) int {
	res := r.set_opts(key, value, SetOpts{
		nx: true
	})
	return if res == true { 1 } else { 0 }
}

pub fn (mut r Redis) setrange(key string, offset int, value string) !int {
	res := r.send_cmd('SETRANGE "${key}" ${offset} "${value}"')!
	return res.int()
}

pub fn (mut r Redis) setex(key string, seconds int, value string) bool {
	return r.set_opts(key, value, SetOpts{
		ex: seconds
	})
}

pub fn (mut r Redis) set(key string, value string) bool {
	res := r.send_cmd('SET "${key}" "${value}"') or { return false }
	return res.starts_with(ok_flag)
}
