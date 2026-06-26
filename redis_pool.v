module vredis

import sync
import time

// Pool-level errors shared across the package.
pub const err_pool_exhausted = error('vredis: connection pool exhausted')

pub const err_conn_closed = error('vredis: connection closed')

pub const err_conn_no_active = error('vredis: client no active')

pub const err_read_message = error('vredis: read message error')

// DialFn is the factory function used by a Pool to create new connections.
pub type DialFn = fn () !&Redis

// PoolOpt configures a connection pool.
@[params]
pub struct PoolOpt {
pub:
	dial               DialFn                     = unsafe { nil } // factory for new connections
	max_active         int                        = 10             // upper bound on simultaneously borrowed connections
	idle_timeout       i64                        = 600            // seconds an idle connection may sit in the pool before being discarded
	max_conn_life_time i64                        = 600            // max seconds a connection may live from creation
	test_on_borrow     fn (mut ActiveRedisConn) ! = unsafe { nil } // optional health-check invoked on every borrow
}

// PoolStats is a snapshot of the pool's internal counters at a point
// in time. It is returned by Pool.stats() for observability and
// debugging.
pub struct PoolStats {
pub:
	active     int // connections currently borrowed (not idle)
	idle       int // connections sitting in the idle channel
	max_active int // configured upper bound on active connections
	is_closed  bool
}

// Pool is a bounded, channel-backed connection pool.
//
// Concurrency model
// ------------------
// The `active` counter (protected by `mu`) bounds the number of
// connections that are currently borrowed. Idle connections live in a
// buffered channel whose capacity equals `max_active`.
//
// The mutex is held only for O(1) bookkeeping (counter / flag updates),
// never during network I/O. This means that a slow dial() in one
// goroutine does not block a get() that can reuse an idle connection.
//
// Lifecycle
// ---------
//  1. get()  → reserve() a slot, reuse idle or dial fresh, return conn.
//  2. release() → put() the conn back (or close it if the pool is closed).
//  3. close() → mark closed, drain idle conns. Borrowed conns are
//     closed when their owners call release().
//
// The idle channel is intentionally never closed. Closing it would
// race with concurrent put() calls and cause a panic on send. Instead,
// put() checks is_closed under the mutex and closes the connection
// directly when the pool is shut down.
pub struct Pool {
mut:
	is_closed   bool
	active      int // connections currently borrowed (not in the channel)
	idle        int // connections sitting in the idle channel
	opt         PoolOpt
	connections chan &ActiveRedisConn
	mu          &sync.Mutex
}

// new_pool creates a pool. `opt.dial` must be non-nil.
pub fn new_pool(opt PoolOpt) !&Pool {
	if isnil(opt.dial) {
		return error('vredis: invalid dial fn setting')
	}
	if opt.max_active <= 0 {
		return error('vredis: max_active must be positive')
	}
	return &Pool{
		opt:         opt
		mu:          sync.new_mutex()
		connections: chan &ActiveRedisConn{cap: opt.max_active}
	}
}

// reserve increments the active counter if the pool is open and below
// the max_active bound. It returns an error otherwise. The mutex is
// released before returning so the caller can perform I/O without
// holding it.
@[inline]
fn (mut p Pool) reserve() ! {
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}
	if p.is_closed {
		return err_conn_closed
	}
	if p.active >= p.opt.max_active {
		return err_pool_exhausted
	}
	p.active++
}

// release decrements the active counter. It is the symmetric partner
// of reserve() and is used when a borrowed connection is discarded
// (closed) rather than returned to the channel.
@[inline]
fn (mut p Pool) release() {
	p.mu.@lock()
	p.active--
	p.mu.unlock()
}

// is_conn_valid checks the connection's age and idle time against the
// pool's configured limits. Expired connections are discarded lazily
// on borrow.
@[inline]
fn (p &Pool) is_conn_valid(c &ActiveRedisConn) bool {
	now := time.now().unix()
	if p.opt.max_conn_life_time > 0 && now - c.active_time >= p.opt.max_conn_life_time {
		return false
	}
	if p.opt.idle_timeout > 0 && now - c.put_in_time >= p.opt.idle_timeout {
		return false
	}
	return true
}

// get borrows a connection from the pool.
//
// Flow:
//  1. reserve() a slot (fails fast if pool is exhausted or closed).
//  2. Try to reuse an idle connection from the channel. Each candidate
//     is validated for age/idle-time and optionally health-checked via
//     test_on_borrow. Invalid connections are closed and the loop
//     continues without consuming a new slot.
//  3. If no idle connection is available, dial a new one. A dial
//     failure releases the reserved slot and propagates the error.
//
// The loop is guaranteed to either return a valid connection or
// propagate an error: step 2 reuses an idle conn or falls through to
// step 3, and step 3 either returns a fresh conn or returns the dial
// error (after releasing the slot).
pub fn (mut p Pool) get() !&ActiveRedisConn {
	p.reserve()!

	for {
		select {
			mut client := <-p.connections {
				// Account for the connection leaving the idle queue.
				p.mu.@lock()
				p.idle--
				p.mu.unlock()

				// Validate the idle connection before handing it out.
				if !p.is_conn_valid(client) {
					client.close() or {}
					continue
				}
				if !isnil(p.opt.test_on_borrow) {
					p.opt.test_on_borrow(mut client) or {
						client.close() or {}
						continue
					}
				}
				client.is_active = true
				return client
			}
			else {
				// No idle connection — dial a fresh one.
				mut fresh := p.opt.dial() or {
					p.release()
					return err
				}
				return &ActiveRedisConn{
					active_time: time.now().unix()
					pool:        unsafe { &p }
					Redis:       fresh
				}
			}
		}
	}
	// Unreachable — the for loop above either returns a connection or
	// propagates a dial error. V's compiler requires an explicit return.
	return error('vredis: unreachable in Pool.get()')
}

// put returns a borrowed connection to the pool. If the pool is closed
// or the channel is full, the connection is closed instead.
//
// The is_closed check is performed under the mutex. If the pool is
// open, active is decremented and the connection is pushed to the
// channel outside the lock (non-blocking; closes the conn if the
// channel is full). If the pool is closed, the connection is closed
// directly.
pub fn (mut p Pool) put(mut client ActiveRedisConn) {
	p.mu.@lock()
	if p.is_closed {
		p.mu.unlock()
		client.close() or {}
		return
	}
	if !client.is_active {
		// Already returned — prevent double-release.
		p.mu.unlock()
		return
	}
	p.active--
	client.is_active = false
	client.put_in_time = time.now().unix()
	p.mu.unlock()

	// Non-blocking push back into the channel. If the channel is full
	// (more idle conns than max_active, which shouldn't happen but is
	// defensive), close the connection.
	select {
		p.connections <- client {
			p.mu.@lock()
			p.idle++
			p.mu.unlock()
		}
		else {
			client.close() or {}
		}
	}
}

// stats returns a snapshot of the pool's internal counters for
// observability and debugging.
pub fn (mut p Pool) stats() PoolStats {
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}
	return PoolStats{
		active:     p.active
		idle:       p.idle
		max_active: p.opt.max_active
		is_closed:  p.is_closed
	}
}

// close marks the pool as closed and discards all idle connections.
// Connections that are currently borrowed are not closed here; they
// will be closed when their caller invokes release() (which calls
// put(), and put() closes the conn when is_closed is true).
//
// The idle channel is not closed to avoid racing with concurrent
// put() calls. It will be garbage-collected when the Pool itself is
// dropped.
pub fn (mut p Pool) close() {
	p.mu.@lock()
	if p.is_closed {
		p.mu.unlock()
		return
	}
	p.is_closed = true
	p.mu.unlock()

	// Drain idle connections.
	for {
		select {
			mut client := <-p.connections {
				client.close() or {}
			}
			else {
				break
			}
		}
	}

	// All idle connections have been closed.
	p.mu.@lock()
	p.idle = 0
	p.mu.unlock()
}
