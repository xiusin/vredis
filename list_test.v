module vredis

fn test_list()! {
	mut redis := new_client()!
	defer {
		redis.close() or {}
	}
	assert redis.flushall()!
	assert redis.lpush('list', 'v2', 'v1')! == 2
	assert redis.rpush('list', 'v3', 'v4')! == 4
	assert redis.llen('list')! == 4
	assert redis.lpop('list')! == 'v1'
	assert redis.rpop('list')! == 'v4'
	assert redis.lset('list', 0, 'xiusin')!
	assert redis.lindex('list', 0)! == 'xiusin'
	assert redis.lrem('list', 0, 'xiusin')! == 1
	assert redis.linsert('list', 'BEFORE', 'v3', 'v3_before_value')! == 2
	assert redis.lindex('list', 0)! == 'v3_before_value'
	assert redis.ltrim('list', 0, 0)!
	assert redis.llen('list')! == 1
	assert redis.rpushx('no_exists_list', 'v1', 'v2')! == 0
	assert redis.lpush('list1', 'l1', 'l2')! == 2
	assert redis.lpush('list2', 'l3', 'l4')! == 2
	assert redis.rpoplpush('list1', 'list2')! == 'l1'
	assert redis.lrange('list', 0, -1)!.str() == "['v3_before_value']"
	assert redis.rpushx('list', 'rpushx')! == 2
	assert redis.blpop('list', 2)!.value == 'v3_before_value'
	assert redis.brpop('list', 2)!.value == 'rpushx'
}
