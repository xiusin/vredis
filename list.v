module vredis

pub struct BPopReply {
pub:
	key   string
	value string
}

fn (mut r Redis) push(cmd string, key string, value string, values []string) !int {
	mut args := [CmdArg(key), CmdArg(value)]
	for val in values {
		args << val
	}

	return r.send(cmd, ...args)!.int()
}

pub fn (mut r Redis) lpush(key string, value string, values ...string) !int {
	return r.push('LPUSH', key, value, values)!
}

pub fn (mut r Redis) rpush(key string, value string, values ...string) !int {
	return r.push('RPUSH', key, value, values)!
}

pub fn (mut r Redis) lpop(key string) !string {
	return r.send('LPOP', key)!
}

pub fn (mut r Redis) rpop(key string) !string {
	return r.send('RPOP', key)!
}

pub fn (mut r Redis) lset(key string, index i64, value string) !bool {
	return r.send('LSET', key, index, value)!.starts_with(ok_flag)
}

pub fn (mut r Redis) llen(key string) !int {
	return r.send('LLEN', key)!.int()
}

pub fn (mut r Redis) lindex(key string, index int) !string {
	return r.send('LINDEX', key, index)!
}

pub fn (mut r Redis) lrem(key string, count int, value string) !int {
	return r.send('LREM', key, count, value)!.int()
}

pub fn (mut r Redis) ltrim(key string, start int, stop int) !bool {
	return r.send('LTRIM', key, start, stop)!.starts_with(ok_flag)
}

pub fn (mut r Redis) rpoplpush(source string, destination string) !string {
	return r.send('RPOPLPUSH', source, destination)!
}

pub fn (mut r Redis) rpushx(key string, value string, values ...string) !int {
	return r.push('RPUSHX', key, value, values)!
}

pub fn (mut r Redis) linsert(key string, pos string, pivot string, value string) !int {
	if pos.to_upper() !in ['BEFORE', 'AFTER'] {
		return error('pos failed: BEFORE|AFTER')
	}
	return r.send('LINSERT', key, pos, pivot, value)!.int()
}

pub fn (mut r Redis) lrange(key string, start int, stop int) ![]string {
	return r.send('LRANGE', key, start, stop)!.split('\r\n')
}

fn (mut r Redis) bpop(command string, key string, timeout int, keys ...string) !BPopReply {
	mut args := [CmdArg(key)]
	args << keys
	for it in keys {
		args << it
	}
	args << timeout

	ret := r.send('BLPOP', ...args)!
	if ret == '(nil)' {
		return error('block has timeout!')
	}
	lk, value := ret.split_once('\r\n') or { return error('parse reply content failed') }
	return BPopReply{
		key: lk
		value: value
	}
}

pub fn (mut r Redis) brpop(key string, timeout int, keys ...string) !BPopReply {
	return r.bpop('BRPOP', key, timeout, ...keys)!
}

pub fn (mut r Redis) blpop(key string, timeout int, keys ...string) !BPopReply {
	return r.bpop('BLPOP', key, timeout, ...keys)!
}
