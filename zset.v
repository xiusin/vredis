module vredis

// ZrangeOpt carries optional LIMIT / WITHSCORES flags for the
// ZRANGEBYSCORE / ZRANGEBYLEX family of commands.
@[params]
pub struct ZrangeOpt {
pub:
	withscores bool
	offset     int
	count      int
}

// zadd adds one or more score/member pairs to a sorted set.
// `source1` is the score of `member1`; the variadic arguments must
// alternate score (string-encoded, e.g. "1.5" / "-inf" / "+inf") and
// member, e.g. zadd('k', 1.0, 'a', '2.5', 'b').
pub fn (mut r Redis) zadd(key string, source1 f64, member1 string, source_member ...string) !int {
	if source_member.len % 2 != 0 {
		return error('Scores and members must appear in pairs')
	}
	mut args := []CmdArg{cap: 3 + source_member.len}
	args << key
	args << source1
	args << member1

	for member in source_member {
		args << member
	}

	return r.send('ZADD', ...args)!.int()
}

@[inline]
pub fn (mut r Redis) zcard(key string) !int {
	return r.send('ZCARD', key)!.int()
}

@[inline]
pub fn (mut r Redis) zcount(key string, min string, max string) !int {
	return r.send('ZCOUNT', key, min, max)!.int()
}

@[inline]
pub fn (mut r Redis) zlexcount(key string, min string, max string) !int {
	return r.send('ZLEXCOUNT', key, min, max)!.int()
}

@[inline]
pub fn (mut r Redis) zincrby(key string, increment f64, member string) !f64 {
	return r.send('ZINCRBY', key, increment, member)!.f64()
}

pub fn (mut r Redis) zinterstore(destination string, numkeys int, key string, keys ...string) !int {
	mut args := [CmdArg(destination)]
	args << numkeys
	args << key
	for it in keys {
		args << it
	}
	return r.send('ZINTERSTORE', ...args)!.int()
}

pub fn (mut r Redis) zunionstore(destination string, numkeys int, key string, keys ...string) !int {
	mut args := [CmdArg(destination)]
	args << numkeys
	args << key
	for it in keys {
		args << it
	}
	return r.send('ZUNIONSTORE', ...args)!.int()
}

@[inline]
pub fn (mut r Redis) zrank(key string, member string) !int {
	return r.send('ZRANK', key, member)!.int()
}

// zscore returns the score of a member as a float. Redis returns the
// score as a bulk string (e.g. "1" or "2.5"), so f64() is the correct
// accessor. Returns err_nil when the member does not exist.
pub fn (mut r Redis) zscore(key string, member string) !f64 {
	reply := r.send('ZSCORE', key, member)!
	if reply.kind == .nil_reply {
		return err_nil
	}
	return reply.f64()
}

pub fn (mut r Redis) zrem(key string, member1 string, member2 ...string) !int {
	mut args := [CmdArg(key)]
	args << member1
	for it in member2 {
		args << it
	}
	return r.send('ZREM', ...args)!.int()
}

@[inline]
pub fn (mut r Redis) zremrangebyscore(key string, min string, max string) !int {
	return r.send('ZREMRANGEBYSCORE', key, min, max)!.int()
}

@[inline]
pub fn (mut r Redis) zremrangebyrank(key string, start int, stop int) !int {
	return r.send('ZREMRANGEBYRANK', key, start, stop)!.int()
}

@[inline]
pub fn (mut r Redis) zremrangebylex(key string, min string, max string) !int {
	return r.send('ZREMRANGEBYLEX', key, min, max)!.int()
}

pub fn (mut r Redis) zrange(key string, start int, stop int, withsources ...bool) ![]string {
	mut args := [CmdArg(key)]
	args << start
	args << stop
	if withsources.len > 0 && withsources[0] {
		args << 'WITHSCORES'
	}
	return r.send('ZRANGE', ...args)!.strings()
}

pub fn (mut r Redis) zrangebyscore(key string, start string, stop string, opt ZrangeOpt) ![]string {
	mut args := [CmdArg(key)]
	args << start
	args << stop
	if opt.withscores {
		args << 'WITHSCORES'
	}
	if opt.count > 0 {
		args << 'LIMIT'
		args << opt.offset
		args << opt.count
	}
	return r.send('ZRANGEBYSCORE', ...args)!.strings()
}

pub fn (mut r Redis) zrangebylex(key string, start string, stop string, opt ZrangeOpt) ![]string {
	mut args := [CmdArg(key)]
	args << start
	args << stop
	if opt.count > 0 {
		args << 'LIMIT'
		args << opt.offset
		args << opt.count
	}
	return r.send('ZRANGEBYLEX', ...args)!.strings()
}

pub fn (mut r Redis) zrevrange(key string, start int, stop int, withsources ...bool) ![]string {
	mut args := [CmdArg(key)]
	args << start
	args << stop
	if withsources.len > 0 && withsources[0] {
		args << 'WITHSCORES'
	}
	return r.send('ZREVRANGE', ...args)!.strings()
}

// zrevbyscore returns members with scores in the range [min, max] in
// reverse (descending) order via ZREVRANGEBYSCORE.
//
// Note: Redis's native syntax is `ZREVRANGEBYSCORE key max min`, so the
// parameters are ordered max-first to match. `max`/`min` accept score
// expressions such as "1.5", "-inf", "+inf", or "(2.5" for an exclusive
// bound.
//
// Bug fix: the previous implementation both used the wrong parameter
// order (min, max) and restricted the bounds to int, which made the
// command return the wrong range and prevented -inf/+inf/float usage.
pub fn (mut r Redis) zrevbyscore(key string, max string, min string) ![]string {
	return r.send('ZREVRANGEBYSCORE', key, max, min)!.strings()
}

@[inline]
pub fn (mut r Redis) zrevrank(key string, member string) !int {
	return r.send('ZREVRANK', key, member)!.int()
}

// zscan iterates sorted-set members using the cursor-based ZSCAN command.
pub fn (mut r Redis) zscan(key string, opts ScanOpts) !ScanReply {
	mut args := [CmdArg(key)]
	args << opts.cursor
	if opts.pattern.len > 0 {
		args << 'MATCH'
		args << opts.pattern
	}
	if opts.count > 0 {
		args << 'COUNT'
		args << opts.count
	}
	reply := r.send('ZSCAN', ...args)!
	return parse_scan_reply(reply)
}
