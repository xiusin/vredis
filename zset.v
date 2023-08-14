module vredis

import strconv

[params]
pub struct ZrangeOpt {
	withscores bool
	offset     int
	count      int
}

pub fn (mut r Redis) zadd(key string, source1 int, member1 string, source_member ...string) !int {
	if source_member.len % 2 != 0 {
		return error('Scores and members must appear in pairs')
	}
	mut args := []CmdArg{cap: 3 + source_member.len}

	args << key
	args << source1
	args << member1

	for i, member in source_member {
		if i % 2 == 0 {
			strconv.atoi(member)!
		}
		args << member
	}

	return r.send('ZADD', ...args)!.int()
}

pub fn (mut r Redis) zcard(key string) !int {
	return r.send('ZCARD', key)!.int()
}

pub fn (mut r Redis) zcount(key string, min int, max int) !int {
	return r.send('ZCOUNT', key, min, max)!.int()
}

pub fn (mut r Redis) zlexcount(key string, min string, max string) !int {
	return r.send('ZLEXCOUNT', key, min, max)!.int()
}

pub fn (mut r Redis) zincrby(key string, increment int, member string) !int {
	return r.send('ZINCRBY', key, increment, member)!.int()
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

pub fn (mut r Redis) zrank(key string, member string) !int {
	return r.send('ZRANK', key, member)!.int()
}

pub fn (mut r Redis) zscore(key string, member string) !int {
	return r.send('ZSCORE', key, member)!.int()
}

pub fn (mut r Redis) zrem(key string, member1 string, member2 ...string) !int {
	mut args := [CmdArg(key)]
	args << member1
	for it in member2 {
		args << it
	}

	return r.send('ZREM', ...args)!.int()
}

pub fn (mut r Redis) zremrangebyscore(key string, min int, max int) !int {
	return r.send('ZREMRANGEBYSCORE', key, min, max)!.int()
}

pub fn (mut r Redis) zremrangebyrank(key string, start int, stop int) !int {
	return r.send('ZREMRANGEBYRANK', key, start, stop)!.int()
}

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

	return r.send('ZRANGE', ...args)!.split('\r\n')
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

	return r.send('ZRANGEBYSCORE', ...args)!.split('\r\n')
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
	return r.send('ZRANGEBYLEX', ...args)!.split('\r\n')
}

pub fn (mut r Redis) zrevrange(key string, start int, stop int, withsources ...bool) ![]string {
	mut args := [CmdArg(key)]
	args << start
	args << stop
	if withsources.len > 0 && withsources[0] {
		args << 'WITHSCORES'
	}
	return r.send('ZREVRANGE', ...args)!.split('\r\n')
}

pub fn (mut r Redis) zrevbyscore(key string, min int, max int) ![]string {
	return r.send('ZREVBYSCORE', key, min, max)!.split('\r\n')
}

pub fn (mut r Redis) zrevrank(key string, member string) !int {
	return r.send('ZREVRANK', key, member)!.int()
}

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

	next_cursor, members := r.send('ZSCAN', ...args)!.split_once('\r\n') or {
		return error('parse reply content failed')
	}
	return ScanReply{
		cursor: next_cursor.u64()
		result: members.split('\r\n')
	}
}
