module vredis

fn test_set()! {
	mut redis := new_client()!
	defer {
		redis.close() or {}
	}

	// for i in 0 .. 1000 {
	// 	redis.sadd('sets', 'v${i + 30}')
	// }
	//
	// println(redis.sadd('sets2', 'v21', 'v22', 'v30'))
	//
	// println('scard = ${redis.scard('sets')}')
	// println('sdiff = ${redis.sdiff('sets', 'sets2')}')
	// println('sunion = ${redis.sunion('sets', 'sets2')}')
	// println('sinter = ${redis.sinter('sets', 'sets2')}')
	// println('sinterstore = ${redis.sinterstore('sinterstore', 'sets', 'sets2')}')
	// println('sismember = ${redis.sismember('sets', 'v2')}')
	// println('sismember = ${redis.sismember('sets', 'v5')}')
	println(redis.sscan('sets', 0)!)

}
