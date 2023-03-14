module vredis

fn (mut r Redis) hdel(key string, field string, fields ...string) bool {
	mut keys := [field]
	keys << fields
	res := r.send('HDEL ${key} ${keys.join(' ')}') or { return false }
	return res != ':0'
}

fn (mut r Redis) hexists(key string, field string) bool {
	res := r.send('HEXISTS ${key} ${field}') or { return false }
	return res == ':1'
}

fn (mut r Redis) hget(key string, field string) !string {
	return r.send('HGET ${key} ${field}')!
}

fn (mut r Redis) hgetall(key string) !map[string]string {
	res := r.send('HGETALL ${key}')!.split('\r\n')
	mut data :=  map[string]string{}
	for i := 0; i < res.len; i+=2 {
		data[res[i]] = res[i + 1]
	}
	return data
}

fn (mut r Redis) hincrby(key string, field string, incr_num int) !i64 {
	res := r.send('HINCRBY ${key} ${field} ${incr_num}')!
	return res[1..].i64()
}

fn (mut r Redis) hincrbyfloat(key string, field string, incr_num f64) !f64 {
	res := r.send('HINCRBYFLOAT ${key} ${field} ${incr_num}')!
	return res[1..].f64()
}

fn (mut r Redis) hsetnx(key string, field string, value string) bool {
	res := r.send('HSETNX ${key} ${field} "${value}"') or { return false }
	return res == ':1'
}

fn (mut r Redis) hset(key string, field string, value string) bool {
	res := r.send('HSET ${key} ${field} "${value}"') or { return false }
	return res in [':1', ':0']
}

fn (mut r Redis) hkeys(key string) []string {
	res := r.send('HKEYS ${key}') or { return [] }
	return res.split('\r\n')
}

fn (mut r Redis) hlen(key string) int {
	res := r.send('HLEN ${key}') or { return 0 }
	return res[1..].int()
}

fn (mut r Redis) hvals(key string) []string {
	res := r.send('HVALS ${key}') or { return [] }
	return res.split('\r\n')
}
