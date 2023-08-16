module vredis

[params]
pub struct ScanOpts {
	pattern string
	count   i64
	cursor  u64
}

pub struct ScanReply {
	cursor u64
	result []string
}

pub fn (mut r Redis) sadd(key string, member1 string, member2 ...string) !int {
	mut args := [CmdArg(key), CmdArg(member1)]
	for it in member2 {
		args << it
	}

	return r.send('SADD', ...args)!.int()
}

pub fn (mut r Redis) scard(key string) !int {
	return r.send('SCARD', key)!.int()
}

pub fn (mut r Redis) sismember(key string, value string) !bool {
	return r.send('SISMEMBER', key, value)!.int() == 1
}

pub fn (mut r Redis) spop(key string) !string {
	return r.send('SPOP', key)!.bytestr()
}

pub fn (mut r Redis) smove(source string, destination string, member string) !bool {
	return r.send('SMOVE', source, destination, member)!.int() == 1
}

pub fn (mut r Redis) srandmember(key string, cnt ...int) ![]string {
	count := if cnt.len > 0 { cnt[0] } else { 1 }
	ret := r.send('SRANDMEMBER', key, count)!.data().bytestr()
	return if ret.len > 0 {
		ret.split(crlf)
	} else {
		[]string{}
	}
}

pub fn (mut r Redis) srem(key string, member1 string, member2 ...string) !int {
	mut args := [CmdArg(key)]
	args << member1
	for it in member2 {
		args << it
	}

	return r.send('SREM', ...args)!.int()
}

fn (mut r Redis) multi_keys_handle(cmd string, key string, keys []string) ![]string {
	mut args := [CmdArg(key)]
	for it in keys {
		args << it
	}

	return r.send('${cmd}', ...args)!.strings()
}

fn (mut r Redis) multi_keys_store_handle(cmd string, key string, keys []string) !int {
	mut args := [CmdArg(key)]
	for it in keys {
		args << it
	}

	return r.send(cmd, ...args)!.int()
}

pub fn (mut r Redis) sunion(key string, keys ...string) ![]string {
	return r.multi_keys_handle('SUNION', key, keys)!
}

pub fn (mut r Redis) sunionstore(key string, keys ...string) !int {
	return r.multi_keys_store_handle('SUNIONSTORE', key, keys)
}

pub fn (mut r Redis) sdiff(key string, keys ...string) ![]string {
	return r.multi_keys_handle('SDIFF', key, keys)!
}

pub fn (mut r Redis) sdiffstore(key string, keys ...string) !int {
	return r.multi_keys_store_handle('SDIFFSTORE', key, keys)
}

pub fn (mut r Redis) sinter(key string, keys ...string) ![]string {
	return r.multi_keys_handle('SINTER', key, keys)!
}

pub fn (mut r Redis) smembers(key string) ![]string {
	return r.send('SMEMBERS', key)!.strings()
}

pub fn (mut r Redis) sinterstore(key string, keys ...string) !int {
	return r.multi_keys_store_handle('SINTERSTORE', key, keys)
}

pub fn (mut r Redis) sscan(key string, opts ScanOpts) !ScanReply {
	mut args := [CmdArg(key), CmdArg(opts.cursor)]

	if opts.pattern.len > 0 {
		args << 'MATCH'
		args << opts.pattern
	}
	if opts.count > 0 {
		args << 'COUNT'
		args << opts.count
	}

	next_cursor, members := r.send('SSCAN', ...args)!.data().bytestr().split_once(crlf) or {
		return error('error msg')
	}
	return ScanReply{
		cursor: next_cursor.u64()
		result: members.split(crlf)
	}
}
