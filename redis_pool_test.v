module vredis

import time

// test_pool verifies the connection pool lifecycle:
//   - max_active bounds the number of borrowed connections
//   - releasing a connection makes it available for reuse
//   - expired connections (max_conn_life_time) are replaced with fresh dials
//   - stats() reports correct active/idle counters
//   - discard() releases the slot without returning the conn to the idle queue
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

	// Initially the pool is empty.
	stats := pool.stats()
	assert stats.active == 0
	assert stats.idle == 0
	assert stats.max_active == 2
	assert stats.is_closed == false

	mut client := pool.get()!
	mut client1 := pool.get()!

	// Both slots are borrowed.
	s1 := pool.stats()
	assert s1.active == 2
	assert s1.idle == 0

	// Pool is exhausted — a third get must fail.
	pool.get() or { assert err == err_pool_exhausted }

	// Releasing `client` returns it to the pool. A subsequent get should
	// succeed (reusing the released connection).
	client.release()

	s2 := pool.stats()
	assert s2.active == 1
	assert s2.idle == 1

	mut got := pool.get()!

	// Pool should be exhausted again (2 active, 0 idle).
	s3 := pool.stats()
	assert s3.active == 2
	assert s3.idle == 0

	// Both connections can execute commands.
	assert client1.ping()!
	assert got.ping()!

	// discard() releases the slot without returning the conn to the idle
	// queue. The next get() will dial a fresh connection.
	got.discard()

	s4 := pool.stats()
	assert s4.active == 1
	assert s4.idle == 0

	mut got3 := pool.get()!
	assert got3.ping()!
	got3.release()
	client1.release()

	// Wait for connections to expire past max_conn_life_time.
	time.sleep(time.second)

	// After expiration, get should still work (dials fresh connection).
	mut got2 := pool.get()!
	assert got2.ping()!

	got2.release()
	pool.close()

	// After close, stats reflects the closed state.
	s5 := pool.stats()
	assert s5.is_closed == true
}
