module vredis

fn test_script() ! {
	multi_str := 'a

b

c

d'
	mut redis := new_client()!
	defer {
		redis.close() or {}
	}

	redis.flushall()!

	println(redis.eval("return {1,2,{3,'hello world'}}", 0)!.strings()) // no support

	// assert redis.eval('return 10', 0)! == '10'
	// println(redis.eval("return {1, 2}", 0)!.split('\r\n'))
	// assert redis.eval('return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}', 2, "a", "b", "c", "d")! == multi_str
	// println(redis.eval("return {1, 2}", 0)!.split('\r\n'))
	// println(redis.eval("return {1,2,3.3333,'foo',nil,'bar'}", 0)!.split('\r\n') )// no support
	// redis.eval("return tostring(3.3333)", 0)!
	// println(redis.eval("return {err='My Error'}", 0) or {
	// 	':0'
	// })
	// redis.eval("return redis.error_reply('My Error')", 0) or {
	// 	':1'
	// }
	// redis.set('foo', 'bar')!
	// redis.eval("return redis.call('get','foo')", 0)!
	// redis.eval("return redis.call('HKEYS','website')", 0)!
	// redis.eval("return redis.call('HVALS','website')", 0)!
	// println(redis.eval("return redis.call('HGETALL', 'website')", 0)!)
	//
	// sha := redis.script_load('return 1')!
	// ret := redis.script_exists(sha, "1111", "222")
	// if ret[sha] {
	// 	println('${sha} exists')
	// }
	// redis.script_flush()
	// println(redis.script_exists(sha))
}
