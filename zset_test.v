module vredis

fn test_set()! {
	mut redis := new_client()!
	defer {
		redis.close() or {}
	}

	assert redis.flushall()!
	assert redis.zadd('sets', 1, 'v1', '2', 'v2')! == 2
	assert redis.zscan('sets', pattern: '*', cursor: 0)!.result.len == 4
	assert redis.zcard('sets') == 2
	assert redis.zrevrank('sets', 'v1')! == 1
	assert redis.zrevrank('sets', 'v2')! == 0
	assert redis.zscore('sets', 'v1')! == 1
	assert redis.zcount('sets', 1, 2) == 2
	assert redis.zlexcount('sets', '-', '+') == 2
	assert redis.zlexcount('sets', '+', '-') == 0
	assert redis.zrank('sets', 'v2')! == 1
	assert redis.zrange('sets', 0, -1)!.str() == "['v1', 'v2']"
	assert redis.zrevrange('sets', 0, -1)!.str() == "['v2', 'v1']"
	assert redis.zrange('sets', 1, 2, true)!.str() == "['v2', '2']"
	assert redis.zrevrange('sets', 1, 2, true)!.str() == "['v1', '1']"
	assert redis.zrangebyscore('sets', "-inf", "+inf", withscores: false)!.str() == "['v1', 'v2']"
	assert redis.zrangebyscore('sets', "-inf", "+inf", withscores: true)!.str() == "['v1', '1', 'v2', '2']"
	assert redis.zrangebyscore('sets', "-inf", "+inf", withscores: true, count: 1)!.str() == "['v1', '1']"
	assert redis.zrangebyscore('sets', "-inf", "+inf", withscores: true, offset: 1, count: 1)!.str() == "['v2', '2']"
	assert redis.zrangebylex('sets', "-", "+", count: 1)!.str() == "['v1']"
	assert redis.zrem('sets', 'v1') == 1
	assert redis.zcard('sets') == 1
	assert redis.zincrby('sets', 10, 'v2') == 12
	assert redis.zscore('sets', 'v2')! == 12
	assert redis.zremrangebyscore('sets', 0, 200)! == 1
	redis.zadd('sets', 100, 'xiusin', '200', 'vlang')!
	assert redis.zremrangebyrank('sets', 0, 0)! == 1
}
