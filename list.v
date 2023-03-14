module vredis

fn (mut r Redis) lpush(key_name string, value string, values ...string) !int {
	mut vals := ['"${value}"']
	for val in values {
		vals << '"${val}"'
	}
	res := r.send('LSET ${key_name} ${vals.join(' ')}') or { return 0 }
	return res[1..].int()
}

pub fn (mut r Redis) lpop(key string) !string {
	res := r.send('LPOP "${key}"')!
	len := res.int()
	if len == -1 {
		return error('key not found')
	}
	return r.socket.read_line()[0..len]
}

pub fn (mut r Redis) rpop(key string) !string {
	res := r.send('RPOP "${key}"')!
	len := res.int()
	if len == -1 {
		return error('key not found')
	}
	return r.socket.read_line()[0..len]
}

pub fn (mut r Redis) llen(key string) !int {
	res := r.send('LLEN "${key}"')!
	rerr := parse_err(res)
	if rerr != '' {
		return error(rerr)
	}
	return res.int()
}
