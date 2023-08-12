module vredis

[params]
pub struct ScanOpts {
	pattern string
	count   i64
	cursor u64
}

pub struct ScanReply {
	cursor u64
	result []string
}

pub fn (mut r Redis) sadd(key string, member1 string, member2 ...string) int {
	mut members := [member1]
	members << member2
	members = members.map('"${it}"')

	return r.send('SADD "${key}" ${members.join(' ')}') or { '0' }.int()
}

pub fn (mut r Redis) scard(key string) int {
	return r.send('SCARD "${key}"') or { '0' }.int()
}

pub fn (mut r Redis) sismember(key string, value string) bool {
	return r.send('SISMEMBER "${key}" "${value}"') or { '0' } == '1'
}

pub fn (mut r Redis) spop(key string) string {
	return r.send('SPOP "${key}"') or { '(nil)' }
}

pub fn (mut r Redis) smove(source string, destination string, member string) bool {
	return r.send('SMOVE "${source}" "${destination}" "${member}"') or { '0' } == '1'
}

pub fn (mut r Redis) srandmember(key string, cnt ...int) ![]string {
	count := if cnt.len > 0 { cnt[0] } else { 1 }
	ret := r.send('SRANDMEMBER "${key}" ${count}')!
	return if ret.len > 0 {
		ret.split('\r\n')
	} else {
		[]string{}
	}
}

pub fn (mut r Redis) srem(key string, member1 string, member2 ...string) int {
	mut members := [member1]
	members << member2
	members = members.map('"${it}"')
	return r.send('SREM "${key}" ${members.join(' ')}') or { '0' }.int()
}

fn (mut r Redis) multi_keys_handle(cmd string, key string, keys []string) ![]string {
	mut all_keys := [key]
	all_keys << keys
	all_keys = all_keys.map('"${it}"')
	return r.send('${cmd} ${all_keys.join(' ')}')!.split('\r\n')
}

fn (mut r Redis) multi_keys_store_handle(cmd string, key string, keys []string) int {
	mut all_keys := [key]
	all_keys << keys
	all_keys = all_keys.map('"${it}"')
	return r.send('${cmd} ${all_keys.join(' ')}') or { '0' }.int()
}

pub fn (mut r Redis) sunion(key string, keys ...string) ![]string {
	return r.multi_keys_handle('SUNION', key, keys)!
}

pub fn (mut r Redis) sunionstore(key string, keys ...string) int {
	return r.multi_keys_store_handle('SUNIONSTORE', key, keys)
}

pub fn (mut r Redis) sdiff(key string, keys ...string) ![]string {
	return r.multi_keys_handle('SDIFF', key, keys)!
}

pub fn (mut r Redis) sdiffstore(key string, keys ...string) int {
	return r.multi_keys_store_handle('SDIFFSTORE', key, keys)
}

pub fn (mut r Redis) sinter(key string, keys ...string) ![]string {
	return r.multi_keys_handle('SINTER', key, keys)!
}

pub fn (mut r Redis) smembers(key string) ![]string {
	return r.send('SMEMBERS "${key}"')!.split("\r\n")
}

pub fn (mut r Redis) sinterstore(key string, keys ...string) int {
	return r.multi_keys_store_handle('SINTERSTORE', key, keys)
}

pub fn (mut r Redis) sscan(key string, opts ScanOpts) !ScanReply {
	mut cmd := 'SSCAN "${key}" ${opts.cursor} '

	if opts.pattern.len > 0 {
		cmd += 'MATCH "${opts.pattern}" '
	}
	if opts.count > 0 {
		cmd += 'COUNT ${opts.count}'
	}

	next_cursor, members := r.send(cmd)!.split_once("\r\n") or {
		return error('parse reply content failed')
	}
	return ScanReply{
		cursor: next_cursor.u64()
		result: members.split("\r\n")
	}
}
