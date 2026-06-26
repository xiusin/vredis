module vredis

// BPopReply holds the result of a blocking pop (BLPOP / BRPOP).
pub struct BPopReply {
pub:
	key   string
	value string
}

// push is the shared implementation for LPUSH / RPUSH / RPUSHX.
pub fn (mut r Redis) push(cmd string, key string, value string, values []string) !int {
	mut args := [CmdArg(key), CmdArg(value)]
	for val in values {
		args << val
	}
	return r.send(cmd, ...args)!.int()
}

@[inline]
pub fn (mut r Redis) lpush(key string, value string, values ...string) !int {
	return r.push('LPUSH', key, value, values)!
}

@[inline]
pub fn (mut r Redis) rpush(key string, value string, values ...string) !int {
	return r.push('RPUSH', key, value, values)!
}

// lpop removes and returns the first element of a list. Returns err_nil
// when the key does not exist or the list is empty.
pub fn (mut r Redis) lpop(key string) !string {
	reply := r.send('LPOP', key)!
	if reply.kind == .nil_reply {
		return err_nil
	}
	return reply.bytestr()
}

// rpop removes and returns the last element of a list. Returns err_nil
// when the key does not exist or the list is empty.
pub fn (mut r Redis) rpop(key string) !string {
	reply := r.send('RPOP', key)!
	if reply.kind == .nil_reply {
		return err_nil
	}
	return reply.bytestr()
}

@[inline]
pub fn (mut r Redis) lset(key string, index i64, value string) !bool {
	return r.send('LSET', key, index, value)!.ok()
}

@[inline]
pub fn (mut r Redis) llen(key string) !int {
	return r.send('LLEN', key)!.int()
}

// lindex returns the element at `index` in a list. Returns err_nil when
// the key does not exist or the index is out of range.
pub fn (mut r Redis) lindex(key string, index int) !string {
	reply := r.send('LINDEX', key, index)!
	if reply.kind == .nil_reply {
		return err_nil
	}
	return reply.bytestr()
}

@[inline]
pub fn (mut r Redis) lrem(key string, count int, value string) !int {
	return r.send('LREM', key, count, value)!.int()
}

@[inline]
pub fn (mut r Redis) ltrim(key string, start int, stop int) !bool {
	return r.send('LTRIM', key, start, stop)!.ok()
}

// rpoplpush atomically pops the tail of `source` and pushes it to the
// head of `destination`. Returns err_nil when `source` does not exist
// or is empty.
pub fn (mut r Redis) rpoplpush(source string, destination string) !string {
	reply := r.send('RPOPLPUSH', source, destination)!
	if reply.kind == .nil_reply {
		return err_nil
	}
	return reply.bytestr()
}

@[inline]
pub fn (mut r Redis) rpushx(key string, value string, values ...string) !int {
	return r.push('RPUSHX', key, value, values)!
}

pub fn (mut r Redis) linsert(key string, pos string, pivot string, value string) !int {
	if pos.to_upper() !in ['BEFORE', 'AFTER'] {
		return error('pos failed: BEFORE|AFTER')
	}
	return r.send('LINSERT', key, pos, pivot, value)!.int()
}

@[inline]
pub fn (mut r Redis) lrange(key string, start int, stop int) ![]string {
	return r.send('LRANGE', key, start, stop)!.strings()
}

// bpop is the shared implementation for BLPOP / BRPOP.
//
// Bug fixes vs. the previous implementation:
//   - Keys were appended twice (once via `args << keys`, once via a
//     `for` loop), producing a malformed command.
//   - The command name was hard-coded to 'BLPOP' instead of using the
//     `command` parameter, so BRPOP never worked.
//   - Reply parsing now uses the typed Reply array instead of fragile
//     CRLF splitting.
pub fn (mut r Redis) bpop(command string, key string, timeout int, keys ...string) !BPopReply {
	mut args := [CmdArg(key)]
	args << keys
	args << timeout

	reply := r.send(command, ...args)!

	// BLPOP/BRPOP return nil (as a nil array) when the timeout expires.
	if reply.kind == .nil_reply || (reply.kind == .array && reply.arr.len == 0) {
		return error('redis: block has timeout')
	}
	if reply.kind != .array || reply.arr.len < 2 {
		return error('redis: invalid bpop reply')
	}

	return BPopReply{
		key:   reply.arr[0].str_val
		value: reply.arr[1].str_val
	}
}

@[inline]
pub fn (mut r Redis) brpop(key string, timeout int, keys ...string) !BPopReply {
	return r.bpop('BRPOP', key, timeout, ...keys)!
}

@[inline]
pub fn (mut r Redis) blpop(key string, timeout int, keys ...string) !BPopReply {
	return r.bpop('BLPOP', key, timeout, ...keys)!
}
