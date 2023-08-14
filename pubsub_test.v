module vredis

fn test_pubsub() ! {
	mut redis := new_client(name: 'rediv_pubsub')!
	defer {
		redis.close() or {}
	}

	redis.flushall()!

	redis.subscribe(["chan1", "chan2"], fn (message string) {
		println(message)
		if message.contains('exit') {
			exit(0)
		}
	})!

}
