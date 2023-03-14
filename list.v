module vredis

fn (mut r Redis) push(cmd string, key string, value string, values []string) !int {
	mut vals := ['"${value}"']
	for val in values {
		vals << '"${val}"'
	}
	res := r.send('${cmd} ${key} ${vals.join(' ')}')!
	return res[1..].int()
}

pub fn  (mut r Redis) lpush( key string, value string, values ...string) !int {
	return r.push('LPUSH', key, value, values)!
}

pub fn  (mut r Redis) rpush( key string, value string, values ...string) !int {
	return r.push('RPUSH', key, value, values)!
}

pub fn (mut r Redis) lpop(key string) !string {
	res := r.send('LPOP "${key}"')!
	return res[..res.len - 2]
}

pub fn (mut r Redis) rpop(key string) !string {
	res := r.send('RPOP "${key}"')!
	return res[..res.len - 2]
}

pub fn  (mut r Redis) lset( key string, index u64, value string) !bool {
	return r.send('LSET "${key}" ${index} "${value}"')!.starts_with(ok_flag)
}

pub fn (mut r Redis) llen(key string) !int {
	res := r.send('LLEN "${key}"')!
	return res[1..].int()
}
