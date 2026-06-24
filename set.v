module vredis

// ScanOpts configures the cursor-based SCAN / SSCAN / ZSCAN commands.
@[params]
pub struct ScanOpts {
pub:
	pattern string
	count   i64
	cursor  u64
}

// ScanReply holds the result of a SCAN-family command: the next cursor
// to continue iteration with and the elements returned in this batch.
pub struct ScanReply {
pub:
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

@[inline]
pub fn (mut r Redis) scard(key string) !int {
	return r.send('SCARD', key)!.int()
}

@[inline]
pub fn (mut r Redis) sismember(key string, value string) !bool {
	return r.send('SISMEMBER', key, value)!.int() == 1
}

@[inline]
pub fn (mut r Redis) spop(key string) !string {
	return r.send('SPOP', key)!.bytestr()
}

@[inline]
pub fn (mut r Redis) smove(source string, destination string, member string) !bool {
	return r.send('SMOVE', source, destination, member)!.int() == 1
}

// srandmember returns one or more random members from a set.
// With no count argument a single member is requested; with a positive
// count the result is an array of distinct members.
pub fn (mut r Redis) srandmember(key string, cnt ...int) ![]string {
	count := if cnt.len > 0 { cnt[0] } else { 1 }
	reply := r.send('SRANDMEMBER', key, count)!
	if reply.kind == .array {
		mut result := []string{cap: reply.arr.len}
		for elem in reply.arr {
			result << elem.str_val
		}
		return result
	}
	if reply.kind == .nil_reply {
		return []string{}
	}
	return [reply.str_val]
}

pub fn (mut r Redis) srem(key string, member1 string, member2 ...string) !int {
	mut args := [CmdArg(key)]
	args << member1
	for it in member2 {
		args << it
	}
	return r.send('SREM', ...args)!.int()
}

// multi_keys_handle sends a command that takes a key plus a variadic
// list of keys and returns a string array (e.g. SUNION, SDIFF, SINTER).
fn (mut r Redis) multi_keys_handle(cmd string, key string, keys []string) ![]string {
	mut args := [CmdArg(key)]
	for it in keys {
		args << it
	}
	return r.send(cmd, ...args)!.strings()
}

// multi_keys_store_handle sends a command that stores its result into a
// destination key (e.g. SUNIONSTORE, SDIFFSTORE, SINTERSTORE).
fn (mut r Redis) multi_keys_store_handle(cmd string, key string, keys []string) !int {
	mut args := [CmdArg(key)]
	for it in keys {
		args << it
	}
	return r.send(cmd, ...args)!.int()
}

@[inline]
pub fn (mut r Redis) sunion(key string, keys ...string) ![]string {
	return r.multi_keys_handle('SUNION', key, keys)!
}

@[inline]
pub fn (mut r Redis) sunionstore(key string, keys ...string) !int {
	return r.multi_keys_store_handle('SUNIONSTORE', key, keys)!
}

@[inline]
pub fn (mut r Redis) sdiff(key string, keys ...string) ![]string {
	return r.multi_keys_handle('SDIFF', key, keys)!
}

@[inline]
pub fn (mut r Redis) sdiffstore(key string, keys ...string) !int {
	return r.multi_keys_store_handle('SDIFFSTORE', key, keys)!
}

@[inline]
pub fn (mut r Redis) sinter(key string, keys ...string) ![]string {
	return r.multi_keys_handle('SINTER', key, keys)!
}

@[inline]
pub fn (mut r Redis) smembers(key string) ![]string {
	return r.send('SMEMBERS', key)!.strings()
}

@[inline]
pub fn (mut r Redis) sinterstore(key string, keys ...string) !int {
	return r.multi_keys_store_handle('SINTERSTORE', key, keys)!
}

// sscan iterates set members using the cursor-based SSCAN command.
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
	reply := r.send('SSCAN', ...args)!
	return parse_scan_reply(reply)
}
