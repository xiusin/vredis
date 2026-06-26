module vredis

fn test_set() ! {
	mut redis := new_client(db: 6)!
	defer {
		redis.close() or {}
	}

	assert redis.flushdb()!
	assert redis.sadd('sets', 'v11', 'v12', 'v_')! == 3
	assert redis.sadd('sets2', 'v21', 'v22', 'v_')! == 3
	assert redis.scard('sets')! == 3
	sdiff1 := redis.sdiff('sets', 'sets2')!
	assert sdiff1.len == 2
	assert 'v11' in sdiff1
	assert 'v12' in sdiff1
	sdiff2 := redis.sdiff('sets2', 'sets')!
	assert sdiff2.len == 2
	assert 'v21' in sdiff2
	assert 'v22' in sdiff2
	assert redis.sunion('sets', 'sets2')!.len == 5
	assert redis.sinter('sets', 'sets2')! == ['v_']
	assert redis.sismember('sets', 'v12')!
	assert redis.sismember('sets', 'v6')! == false
	// assert redis.spop('sets').starts_with('v')
	// assert redis.sadd('sets', 'v_') >= 0
	assert redis.smove('sets', 'set2', 'v_')!
	assert redis.sismember('sets', 'v_')! == false
	assert redis.srandmember('set', 2)!.len == 0
	assert redis.srandmember('sets', 3)!.len == 2
	redis.sadd('sets', 'v111')!
	assert redis.srem('sets', 'v111')! > 0
	redis.sadd('sets', 'v_')!
	assert redis.sinterstore('vredis_sinterstore', 'sets', 'sets2')! == 1
	assert redis.smembers('vredis_sinterstore')! == ['v_']

	for i := 0; i < 100; i++ {
		redis.sadd('vredis_sccan', 'V${i}')!
	}

	println(redis.sscan('vredis_sccan', count: 10)!)
}
