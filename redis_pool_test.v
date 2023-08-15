module vredis

import time

fn test_pool() ! {
	mut pool := new_pool(
		dial: fn () !&Redis {
			return new_client()!
		}
		max_active: 2
		max_conn_life_time: 1
		test_on_borrow: fn (mut conn ActiveRedisConn) ! {
			conn.ping()!
		}
	)!

	mut client := pool.get()!
	mut client1 := pool.get()!

	pool.get() or { assert err == err_pool_exhausted }

	client.release()
	assert client == pool.get()!

	assert client != client1

	client1.release()

	time.sleep(time.second)

	assert client1 != pool.get()!
}
