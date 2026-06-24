module vredis

// Stream commands (XADD / XDEL / XLEN / XTRIM / XRANGE).
//
// Redis Streams are an append-only log data structure. Each entry has a
// server-generated (or caller-specified) ID and a set of field/value pairs.
// The commands here map 1:1 to the Redis X* commands and use the typed
// Reply helpers for parsing.

// xadd appends an entry to a stream. `id` may be '*' to let the server
// generate an ID. The entry is built from a leading field/value pair
// followed by any number of additional field/value pairs.
pub fn (mut r Redis) xadd(key string, id string, field string, value string, field_values ...string) !string {
	mut args := []CmdArg{cap: 4 + field_values.len}
	args << key
	args << id
	args << field
	args << value
	for fv in field_values {
		args << fv
	}
	return r.send('XADD', ...args)!.bytestr()
}

// xdel removes one or more entries from a stream by ID.
pub fn (mut r Redis) xdel(key string, id string, ids ...string) !int {
	mut args := []CmdArg{cap: 2 + ids.len}
	args << key
	args << id
	for it in ids {
		args << it
	}
	return r.send('XDEL', ...args)!.int()
}

// xlen returns the number of entries in a stream.
@[inline]
pub fn (mut r Redis) xlen(key string) !int {
	return r.send('XLEN', key)!.int()
}

// xtrim trims a stream to approximately `count` entries. When `approx`
// is true the '~' flag is used, allowing Redis to trim slightly more
// than `count` for efficiency.
pub fn (mut r Redis) xtrim(key string, count int, approx ...bool) !int {
	mut args := [CmdArg(key), CmdArg('MAXLEN')]
	if approx.len > 0 && approx[0] {
		args << '~'
	}
	args << count
	return r.send('XTRIM', ...args)!.int()
}

// xrange returns entries in the ID range [start, stop] as alternating
// [id, [field, value, ...]] pairs. `start` and `stop` may be '-' / '+'
// to mean the minimum / maximum ID respectively.
pub fn (mut r Redis) xrange(key string, start string, stop string) ![]string {
	reply := r.send('XRANGE', key, start, stop)!
	if reply.kind != .array {
		return []string{}
	}
	// Each element is [id, [field, value, ...]]. Flatten to id + pairs.
	mut out := []string{cap: reply.arr.len * 2}
	for entry in reply.arr {
		if entry.kind != .array || entry.arr.len < 2 {
			continue
		}
		out << entry.arr[0].str_val
		if entry.arr[1].kind == .array {
			for fv in entry.arr[1].arr {
				out << fv.str_val
			}
		}
	}
	return out
}
