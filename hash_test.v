module vredis

fn test_hash() ! {
	mut redis := new_client()!
	defer {
		redis.close() or {}
	}

	assert redis.flushall()!

	assert redis.hset('website', 'api', 'api.vlang.io')!
	assert redis.hset('website', 'www', 'www.vlang.io')!
	assert redis.hset('website', 'vpm', 'vpm.vlang.io')!
	assert redis.hlen('website')! == 3
	assert redis.hexists('website', 'api')!
	assert redis.hexists('website', 'vpc')! == false
	assert redis.hkeys('website')!.bytestr() == "['api', 'www', 'vpm']"
	assert redis.hget('website', 'api')! == 'api.vlang.io'
	assert redis.hgetall('website')!.bytestr() == "{'api': 'api.vlang.io', 'www': 'www.vlang.io', 'vpm': 'vpm.vlang.io'}"
	assert redis.hdel('website', 'api', 'doc')!
	assert redis.hdel('website', 'api', 'doc')! == false
	assert redis.hincrby('website', 'counter', 1)! == 1
	assert redis.hincrbyfloat('website', 'counter', 1.1)! == 2.1
	assert redis.hsetnx('website', 'doc', 'doc.vlang.io')! == true
	assert redis.hsetnx('website', 'doc', 'doc.vlang.io')! == false
	assert redis.hvals('website')!.len == 4
	assert redis.hmget('website', 'doc', 'api')!.len == 2
	assert redis.hmset('website', 'v1', 'v1.vlang.io', 'v2', 'v2.vlang.io')!
}
