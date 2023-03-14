module vredis

fn test_hash()! {
	mut redis := new_client()!
	defer {
		redis.close() or {}
	}

	println(redis.randomkey()!)

	// redis.set('name', 'xiusin')
	// redis.set('age', '18')
	// redis.hset('website', 'baidu1', 'www.baidu.com111')
	// redis.hset('website', 'baidu4', 'www.baidu.com444')
	// println('hlen = ${redis.hlen('website')}')
	// println( 'hkeys = ${redis.hkeys('website')}')
	// println( 'hexits = ${redis.hexists('website', 'baidu')}')
	// println( 'hexits = ${redis.hexists('website', 'baidu1')}')
	// println( 'hget = ${redis.hget('website', 'baidu1')!}')
	// println('hgetall = ${redis.hgetall('website')!}')
	// println('sadd = ${redis.sadd('names', 'zhangsan', 'li si', 'wang W')}')
	// println('SCARD = ${redis.scard('names')}')
	// println('sismember = ${redis.sismember('names', 'zhangsan')}')
	// println('srandmember = ${redis.srandmember('names', 2)}')
	// println(redis.mget('name', 'age', 'address'))
	// println(redis.hincrby('website', 'num', 1)!)

	// println('hvals = ${redis.hvals('website')}')
	// redis.hdel('website', 'num')
	// println('hvals = ${redis.hvals('website')}')

	// println(redis)
	// redis.send('GET name')!
	// println(redis.ping()!)
	// redis.set("name", "xiusin")
	// println(redis.send('GET name')!)
	// os.write_file("info.log", redis.send("INFO")!)!

}
