module vredis

fn test_list()! {
	mut redis := new_client()!
	defer {
		redis.close() or {}
	}
	println(redis.lpush('list', 'v1', 'v2')!)
	println(redis.rpush('list', 'v3', 'v4')!)

	println(redis.lpop('list')!)
	println(redis.lpop('list')!)

	println(redis.rpop('list')!)
	println(redis.rpop('list')!)
	println(redis.llen('list')!)
	println(redis.lset('list', 0, 'xiusin')!)
	println(redis.lpop('list')!)
}
