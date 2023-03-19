module vredis

fn test_pool() {
	mut pool := &Pool{
		max_idle: 0
		max_active: 0
		dial: fn () !Redis {
			return new_client()!
		}
	}

	mut client := pool.get()!
	client.close()!

	client = pool.get()!
	println(pool)

	println('active cnt: ${pool.active_cnt()}')
}
