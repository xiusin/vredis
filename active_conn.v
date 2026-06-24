module vredis

import time

// ActiveRedisConn wraps a Redis connection that has been borrowed from
// a Pool. It tracks the connection's creation time and last-return time
// so the pool can enforce max lifetime and idle timeout policies.
pub struct ActiveRedisConn {
	Redis
pub:
	active_time i64 // unix timestamp at which the underlying connection was created
mut:
	pool        &Pool = unsafe { nil } // owning pool (nil after release on a closed pool)
	put_in_time i64 // unix timestamp of the most recent return to the pool
}

// release returns the connection to its owning pool. After calling
// release the caller must not use the connection again.
//
// If the pool has been closed, the underlying socket is closed instead
// of being returned to the channel.
pub fn (mut c ActiveRedisConn) release() {
	if isnil(c.pool) {
		// Already released or pool was closed — nothing to do.
		return
	}
	c.put_in_time = time.now().unix()
	c.pool.put(mut c)
}
