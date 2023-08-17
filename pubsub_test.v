module vredis

fn test_pub_sub() ! {
	mut pool := new_pool(
		dial: fn () !&Redis {
			return new_client()!
		}
	)!
	defer {
		pool.close()
	}

	go fn [mut pool] () ! {
		mut client := pool.get()!
		defer {
			client.release()
		}

		client.psubscribe(['chan*'], fn (pattern string, channel string, message string) ! {
			println('pattern: ${pattern} 	chan: ${channel} -> message: ${message}')

			if message.contains('message 9') {
				exit(0)
			}
		})!
	}()

	mut client := pool.get()!
	defer {
		client.release()
	}

	for i := 0; i < 10; i++ {
		client.publish('chan${i % 2}', 'message ${i}')!
	}
}
