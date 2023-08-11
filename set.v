module vredis

[params]
pub struct SScanOpts {
	pattern string
	count   i64
}

pub fn (mut r Redis) sadd(key string, member1 string, member2 ...string) int {
	mut members := [member1]
	members << member2
	members = members.map('"${it}"')
	res := r.send('SADD "${key}" ${members.join(' ')}') or { ':0' }
	return res.trim_left(':').int()
}

pub fn (mut r Redis) scard(key string) int {
	res := r.send('SCARD "${key}"') or { ':0' }
	return res.trim_left(':').int()
}

pub fn (mut r Redis) sismember(key string, value string) bool {
	return r.send('SISMEMBER "${key}" "${value}"') or { ':0' } == ':1'
}

pub fn (mut r Redis) spop(key string) string {
	return r.send('SPOP "${key}"') or { '(nil)' }
}

pub fn (mut r Redis) smove(source string, destination string, member string) bool {
	return r.send('SMOVE "${source}" "${destination}" "${member}"') or { ':0' } == ':1'
}

pub fn (mut r Redis) srandmember(key string, cnt ...int) []string {
	count := if cnt.len > 0 { cnt[0] } else { 1 }
	res := r.send('SRANDMEMBER "${key}" ${count}') or { return [] }
	return res.split('\r\n')
}

pub fn (mut r Redis) srem(key string, member1 string, member2 ...string) int {
	mut members := [member1]
	members << member2
	members = members.map('"${it}"')
	res := r.send('SREM "${key}" ${members.join(' ')}') or { ':0' }
	return res.trim_left(':').int()
}

fn (mut r Redis) multi_keys_handle(cmd string, key string, keys []string) []string {
	mut all_keys := [key]
	all_keys << keys
	all_keys = all_keys.map('"${it}"')
	res := r.send('${cmd} ${all_keys.join(' ')}') or { return [] }
	return res.split('\r\n')
}

fn (mut r Redis) multi_keys_store_handle(cmd string, key string, keys []string) int {
	mut all_keys := [key]
	all_keys << keys
	all_keys = all_keys.map('"${it}"')
	res := r.send('${cmd} ${all_keys.join(' ')}') or { ':0' }
	return res.trim_left(':').int()
}

pub fn (mut r Redis) sunion(key string, keys ...string) []string {
	return r.multi_keys_handle('SUNION', key, keys)
}

pub fn (mut r Redis) sunionstore(key string, keys ...string) int {
	return r.multi_keys_store_handle('SUNIONSTORE', key, keys)
}

pub fn (mut r Redis) sdiff(key string, keys ...string) []string {
	return r.multi_keys_handle('SDIFF', key, keys)
}

pub fn (mut r Redis) sdiffstore(key string, keys ...string) int {
	return r.multi_keys_store_handle('SDIFFSTORE', key, keys)
}

pub fn (mut r Redis) sinter(key string, keys ...string) []string {
	return r.multi_keys_handle('SINTER', key, keys)
}

// pub fn (mut r Redis) sinterstore(key string, keys ...string) int {
// 	return r.multi_keys_store_handle('SINTERSTORE', key, keys)
// }

pub struct ScanResult {
	cursor u64
	result []string
}

pub fn (mut r Redis) sscan(key string, cursor i64, opts SScanOpts) !ScanResult {
	mut cmd := 'SSCAN "${key}" ${cursor} '
	if opts.pattern.len > 0 {
		cmd += 'MATCH "${opts.pattern}" '
	}
	if opts.count > 0 {
		cmd += 'COUNT ${opts.count}'
	}
	r.@lock()
	defer {
		r.unlock()
	}
	next_cursor := r.send(cmd)!
	mut res := []string{cap: if opts.count > 0 { int(opts.count) } else { 10 }}
	for {
		line := r.read_reply()!
		if line.len == 0 {
			break
		}
		res << line[0..line.len - 2]
	}
	return ScanResult{
		cursor: next_cursor.u64()
		result: res
	}
}
