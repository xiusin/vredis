module vredis

fn test_string() ! {
	mut redis := new_client()!
	defer {
		redis.close() or {}
	}
	redis.debug = true
	// assert redis.@type("website")! == 'hash'
	// assert redis.ping()! == true
	// assert redis.ttl('website')! == -1
	// assert redis.pttl('website')! == -1
	// redis.set('website', 1.str())
	// println(redis.expire("website", 100000)!)
	// println(redis.ttl("website")!)
	// println(redis.@type("website1111")!)
	println(redis.get("website1111")!)

	println('incr = ${redis.incrby('counter', 1)!}')

}
