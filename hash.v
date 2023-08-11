module vredis

fn (mut r Redis) hdel(key string, field string, fields ...string) bool {
	mut keys := [field]
	keys << fields
	return r.send('HDEL ${key} ${keys.join(' ')}') or { '0' } != '0'
}

fn (mut r Redis) hexists(key string, field string) bool {
	return r.send('HEXISTS ${key} ${field}') or { '0' } == '1'
}

fn (mut r Redis) hget(key string, field string) !string {
	return r.send('HGET ${key} ${field}')!
}

fn (mut r Redis) hgetall(key string) !map[string]string {
	res := r.send('HGETALL ${key}')!.split('\r\n')
	mut data := map[string]string{}
	for i := 0; i < res.len; i += 2 {
		data[res[i]] = res[i + 1]
	}
	return data
}

fn (mut r Redis) hincrby(key string, field string, incr_num int) !i64 {
	return r.send('HINCRBY ${key} ${field} ${incr_num}')!.i64()
}

fn (mut r Redis) hincrbyfloat(key string, field string, incr_num f64) !f64 {
	return r.send('HINCRBYFLOAT ${key} ${field} ${incr_num}')!.f64()
}

fn (mut r Redis) hsetnx(key string, field string, value string) bool {
	return r.send('HSETNX ${key} ${field} "${value}"') or { '0' } == '1'
}

fn (mut r Redis) hset(key string, field string, value string) bool {
	res := r.send('HSET ${key} ${field} "${value}"') or { return false }
	return res in ['1', '0']
}

fn (mut r Redis) hkeys(key string) ![]string {
	return r.send('HKEYS ${key}')!.split('\r\n')
}

fn (mut r Redis) hlen(key string) !int {
	return r.send('HLEN ${key}')!.int()
}

fn (mut r Redis) hvals(key string) ![]string {
	return r.send('HVALS ${key}')!.split('\r\n')
}

fn (mut r Redis) hmget(key string, field string, fields ...string) ![]string {
	mut field_arr := ['"${field}"']
	for i_field in fields {
		field_arr << '"${i_field}"'
	}
	return r.send('HMGET "${key}" ${field_arr.join(' ')}')!.split('\r\n')
}

fn (mut r Redis) hmset(key string, field string, value string, fvs ...string) !bool {
	if fvs.len % 2 != 0 {
		return error('Fields and values must appear in pairs')
	}
	mut params := ['"${field}"', '"${value}"']
	for fv in fvs {
		params << '"${fv}"'
	}
	return r.send('HMSET "${key}" ${params.join(' ')}')!.starts_with(ok_flag)
}

// TODO 实现hscan
fn (mut r Redis) hscan(key string, cursor string, @match string, count ...int) !bool {
	panic('Implementing')
}
