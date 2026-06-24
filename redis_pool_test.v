module vredis

import time

// test_pool verifies the connection pool lifecycle:
//   - max_active bounds the number of borrowed connections
//   - releasing a connection makes it available for reuse
//   - expired connections (max_conn_life_time) are replaced with fresh dials
fn test_pool() ! {
	mut pool := new_pool(
		dial:               fn () !&Redis {
			return new_client(db: 4)!
		}
		max_active:         2
		max_conn_life_time: 1
		test_on_borrow:     fn (mut conn ActiveRedisConn) ! {
			conn.ping()!
		}
	)!

	mut client := pool.get()!
	mut client1 := pool.get()!

	// Pool is exhausted — a third get must fail.
	pool.get() or { assert err == err_pool_exhausted }

	// Releasing `client` returns it to the pool. A subsequent get should
	// succeed (reusing the released connection).
	client.release()
	mut got := pool.get()!

	// Pool should be exhausted again (2 active).
	pool.get() or { assert err == err_pool_exhausted }

	// Both connections can execute commands.
	assert client1.ping()!
	assert got.ping()!

	got.release()
	client1.release()

	// Wait for connections to expire past max_conn_life_time.
	time.sleep(time.second)

	// After expiration, get should still work (dials fresh connection).
	mut got2 := pool.get()!
	assert got2.ping()!

	got2.release()
	pool.close()
}
