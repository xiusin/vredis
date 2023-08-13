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
	mut params := []string{cap: 3 + source_member.len}

	params << [source1.str(), member1]

	for i, member in source_member {
		if i % 2 == 0 {
			strconv.atoi(member)!
		}
	}

	params << source_member

	return r.send('ZADD "${key}" ${params.join(' ')}') or { '0' }.int()
}

pub fn (mut r Redis) zcard(key string) int {
	return r.send('ZCARD "${key}"') or { '0' }.int()
}

pub fn (mut r Redis) zcount(key string, min int, max int) int {
	return r.send('ZCOUNT "${key}" ${min} ${max}') or { '0' }.int()
}

pub fn (mut r Redis) zlexcount(key string, min string, max string) int {
	return r.send('ZLEXCOUNT "${key}" "${min}" "${max}"') or { '0' }.int()
}

pub fn (mut r Redis) zincrby(key string, increment int, member string) int {
	return r.send('ZINCRBY "${key}" ${increment} "${member}"') or { '0' }.int()
}

pub fn (mut r Redis) zrank(key string, member string) !int {
	return r.send('ZRANK "${key}" "${member}"')!.int()
}

pub fn (mut r Redis) zscore(key string, member string) !int {
	return r.send('ZSCORE "${key}" "${member}"')!.int()
}

pub fn (mut r Redis) zrem(key string, member1 string, member2 ...string) int {
	mut members := [member1]
	members << member2
	members = members.map('"${it}"')
	return r.send('ZREM "${key}" ${members.join(' ')}') or { '0' }.int()
}

pub fn (mut r Redis) zremrangebyscore(key string, min int, max int) !int {
	return r.send('ZREMRANGEBYSCORE ${key} ${min} ${max}')!.int()
}

pub fn (mut r Redis) zremrangebyrank(key string, start int, stop int) !int {
	return r.send('ZREMRANGEBYRANK ${key} ${start} ${stop}')!.int()
}

pub fn (mut r Redis) zremrangebylex(key string, min string, max string) !int {
	return r.send('ZREMRANGEBYLEX ${key} ${min} ${max}')!.int()
}

pub fn (mut r Redis) zrange(key string, start int, stop int, withsources ...bool) ![]string {
	return r.send('ZRANGE ${key} ${start} ${stop}${if withsources.len > 0 && withsources[0] {
		' WITHSCORES'
	} else {
		''
	}}')!.split('\r\n')
}

pub fn (mut r Redis) zrevrange(key string, start int, stop int, withsources ...bool) ![]string {
	return r.send('ZREVRANGE ${key} ${start} ${stop}${if withsources.len > 0 && withsources[0] {
		' WITHSCORES'
	} else {
		''
	}}')!.split('\r\n')
}

pub fn (mut r Redis) zrangebyscore(key string, start string, stop string, opt ZrangeOpt) ![]string {
	mut cmd := 'ZRANGEBYSCORE ${key} ${start} ${stop}'

	if opt.withscores {
		cmd += ' WITHSCORES'
	}
	if opt.count > 0 {
		cmd += ' LIMIT ${opt.offset} ${opt.count}'
	}

	return r.send(cmd)!.split('\r\n')
}

pub fn (mut r Redis) zrangebylex(key string, start string, stop string, opt ZrangeOpt) ![]string {
	mut cmd := 'ZRANGEBYLEX ${key} ${start} ${stop}'

	if opt.count > 0 {
		cmd += ' LIMIT ${opt.offset} ${opt.count}'
	}

	return r.send(cmd)!.split('\r\n')
}

pub fn (mut r Redis) zrevrank(key string, member string) !int {
	mut cmd := 'ZREVRANK ${key} ${member}'
	return r.send(cmd)!.int()
}

pub fn (mut r Redis) zscan(key string, opts ScanOpts) !ScanReply {
	mut cmd := 'ZSCAN "${key}" ${opts.cursor} '

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
