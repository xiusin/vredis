module vredis

fn test_redis() {
	mut redis := connect(host: '124.222.103.232', port: 6379, requirepass: 'yuAU702G!!')!

	defer {
		redis.close() or {}
	}

	redis.hset('website', 'baidu1', 'www.baidu.com111')
	redis.hset('website', 'baidu2', 'www.baidu.com111')
	println('hlen = ${redis.hlen('website')}')
	println( 'hkeys = ${redis.hkeys('website')}')
	println( 'hexits = ${redis.hexists('website', 'baidu')}')
	println( 'hexits = ${redis.hexists('website', 'baidu1')}')
	println( 'hget = ${redis.hget('website', 'baidu1')!}')

	// println(redis)
	// redis.send_cmd('GET name')!
	// println(redis.ping()!)
	// redis.set("name", "xiusin")
	// println(redis.send_cmd('GET name')!)
	// os.write_file("info.log", redis.send_cmd("INFO")!)!

}
