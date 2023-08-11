module vredis

fn test_string() ! {
	mut redis := new_client()!
	defer {
		redis.close() or {}
	}
	redis.debug = true

	assert redis.flushall()!

	assert redis.ping()! == true
	assert redis.@type("website")! == 'none'
	assert redis.set('website', 'www')
	assert redis.randomkey()! == 'website'
	assert redis.@type("website")! == 'string'
	assert redis.ttl('website')! == -1
	assert redis.pttl('website')! == -1
	assert redis.get("website")! == 'www'
	assert redis.get('xxxx')! == '(nil)'
	assert redis.incr('vredis_counter')! == 1
	assert redis.incrby('vredis_counter', 2)! == 3
	assert redis.decrby('vredis_counter', 2)! == 1
	assert redis.decr('vredis_counter')! == 0
	assert redis.incrbyfloat('vredis_counter', 1.1)! == 1.1
	assert redis.incrbyfloat('vredis_counter', 2.23)! == 3.33
	assert redis.incrbyfloat('vredis_counter', -3.33)! == 0
	assert redis.append('website', ".vlang.io")! == 12
	assert redis.strlen('website')! == 12
	assert redis.get('website')! == 'www.vlang.io'
	assert redis.getrange('website', 0, 2)! == 'www'
	assert redis.getset('exists', 'exists')! == '(nil)'
	assert redis.getset('exists', 'exists')! == 'exists'
	assert redis.setrange('exists', 0, "mo")! == 6
	assert redis.get('exists')! == 'moists'
	assert redis.mget('exists').str() == "{'exists': 'moists'}"
	assert redis.keys('*')!.len == 3
	assert redis.rename('exists', '_exists')!
	assert redis.exists('exists')! == false
	assert redis.exists('_exists')!
	assert redis.del('exists')! == false
	assert redis.expire('_exists', 1)!
	assert redis.ttl('_exists')! == 1
	assert redis.pttl('_exists')! <= 1000
	assert redis.ttl('website')! == -1
	assert redis.pttl('website')! == -1
	assert redis.renamenx('_exists', 'website')! == false
	assert redis.renamenx('_exists', 'exists')!
	assert redis.setbit('bits', 0,  1)
	assert redis.getbit('bits', 0) == 1
	assert redis.getbit('bits', 1) == 0

}
