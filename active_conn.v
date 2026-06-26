module vredis

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
// of being returned to the channel. Repeated calls to release() are
// safe (idempotent): the second call sees pool == nil and returns
// immediately.
pub fn (mut c ActiveRedisConn) release() {
	if isnil(c.pool) {
		// Already released or pool was closed — nothing to do.
		return
	}
	// put() handles: setting put_in_time, decrementing active,
	// pushing to the channel, or closing the conn if the pool is shut down.
	c.pool.put(mut c)
}

// discard closes the underlying socket and releases the reserved pool
// slot without returning the connection to the idle queue. Use this
// when a borrowed connection is in a bad state (e.g. a protocol error
// was encountered) and must not be reused.
//
// This is distinct from release() (which returns a healthy conn to the
// pool) and from the inherited Redis.close() (which only closes the
// socket without releasing the pool slot).
pub fn (mut c ActiveRedisConn) discard() {
	if !isnil(c.pool) {
		// Release the slot so a new connection can be dialed on the
		// next get(). Set pool to nil so a subsequent release() is a
		// no-op.
		c.pool.release()
		c.pool = unsafe { nil }
	}
	c.Redis.close() or {}
}
