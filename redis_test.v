module vredis

fn test_redis() {
	mut redis := connect(host: '124.222.103.232', port: 6379, requirepass: 'yuAU702G!!')!

	println(redis)
	// println(redis.send_cmd('GET name')!)
}
