module vredis

fn test_stream() ! {
	mut redis := new_client(db: 7)!
	defer {
		redis.close() or {}
	}

	key := 'rediv_stream'

	redis.flushdb()!

	id := redis.xadd(key, '*', 'name', 'vlang')!

	assert redis.xdel(key, id)! == 1

	assert redis.xlen(key)! == 0
}
