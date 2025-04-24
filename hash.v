module vredis

pub fn (mut r Redis) hdel(key string, field string, fields ...string) !bool {
	mut args := [CmdArg(key), CmdArg(field)]
	for it in fields {
		args << it
	}

	return r.send('HDEL', ...args)!.int() != 0
}

pub fn (mut r Redis) hexists(key string, field string) !bool {
	return r.send('HEXISTS', key, field)!.@is(1)
}

pub fn (mut r Redis) hget(key string, field string) !string {
	return r.send('HGET', key, field)!.bytestr()
}

pub fn (mut r Redis) hgetall(key string) !map[string]string {
	res := r.send('HGETALL', key)!.strings()
	mut data := map[string]string{}
	for i := 0; i < res.len; i += 2 {
		data[res[i]] = res[i + 1]
	}
	return data
}

pub fn (mut r Redis) hincrby(key string, field string, incr_num int) !i64 {
	return r.send('HINCRBY', key, field, incr_num)!.i64()
}

pub fn (mut r Redis) hincrbyfloat(key string, field string, incr_num f64) !f64 {
	return r.send('HINCRBYFLOAT', key, field, incr_num)!.f64()
}

pub fn (mut r Redis) hsetnx(key string, field string, value string) !bool {
	return r.send('HSETNX', key, field, value)!.@is(1)
}

pub fn (mut r Redis) hset(key string, field string, value string) !bool {
	res := r.send('HSET', key, field, value)!.int()
	return res in [0, 1]
}

pub fn (mut r Redis) hkeys(key string) ![]string {
	return r.send('HKEYS', key)!.strings()
}

pub fn (mut r Redis) hlen(key string) !int {
	return r.send('HLEN', key)!.int()
}

pub fn (mut r Redis) hvals(key string) ![]string {
	return r.send('HVALS', key)!.strings()
}

pub fn (mut r Redis) hmget(key string, field string, fields ...string) ![]string {
	mut args := [CmdArg(key), CmdArg(field)]
	for it in fields {
		args << it
	}

	return r.send('HMGET', ...args)!.strings()
}

pub fn (mut r Redis) hmset(key string, field string, value string, fvs ...string) !bool {
	if fvs.len % 2 != 0 {
		return error('Fields and values must appear in pairs')
	}
	mut args := [CmdArg(key), CmdArg(field), CmdArg(value)]
	for it in fvs {
		args << it
	}
	return r.send('HMSET', ...args)!.ok()
}

// TODO 实现hscan
fn (mut r Redis) hscan(key string, cursor string, @match string, count ...int) !bool {
	panic('Implementing')
}
