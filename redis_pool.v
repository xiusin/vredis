module vredis

import sync
import time

const err_pool_exhausted = error('vredis: connection pool exhausted')

const err_pool_get_failed = error('vredis: connection pool get redis instance failed')

const err_conn_closed = error('vredis: connection closed')

const err_conn_no_active = error('vredis: client no active')

const err_read_message = error('vredis: read message error')

type DialFn = fn () !&Redis

// PoolOpt Struct representing the options for a connection pool.
@[params]
pub struct PoolOpt {
pub:
	dial               DialFn                     = unsafe { nil } // Function used to establish a connection.
	max_active         int                        = 10             // Maximum number of active connections allowed in the pool.
	idle_timeout       i64                        = 600            // Maximum time in seconds that an idle connection can stay in the pool.
	max_conn_life_time i64                        = 600            // Maximum time in seconds that a connection can stay alive.
	test_on_borrow     fn (mut ActiveRedisConn) ! = unsafe { nil } // Function used to test a connection before borrowing it from the pool.
}

pub struct Pool {
mut:
	active      u64
	opt         PoolOpt
	close       bool
	connections chan &ActiveRedisConn
	mu          &sync.Mutex
}

pub fn new_pool(opt PoolOpt) !&Pool {
	if isnil(opt.dial) {
		return error('invalid dial fn setting')
	}

	return &Pool{
		opt:         opt
		mu:          sync.new_mutex()
		connections: chan &ActiveRedisConn{cap: opt.max_active}
	}
}

pub fn (mut p Pool) get() !&ActiveRedisConn {
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}

	if p.close {
		return err_conn_closed
	}

	if p.active >= p.opt.max_active {
		println('超出了最大连接数 ${p.active}')
		return err_pool_exhausted
	}

	for {
		select {
			mut client := <-p.connections {
				unix := time.now().unix()
				if unix - client.active_time >= p.opt.max_conn_life_time {
					client.close() or {}
					continue
				}

				if unix - client.put_in_time >= p.opt.idle_timeout {
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
				p.active++
				return client
			}
			else {
				mut client := p.opt.dial()!
				p.active++
				return &ActiveRedisConn{
					active_time: time.now().unix()
					pool:        unsafe { &p }
					Redis:       client
				}
			}
		}
	}

	return err_pool_get_failed
}

pub fn (mut p Pool) put(mut client ActiveRedisConn) {
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}

	if p.close {
		return
	}

	if !client.is_active {
		return
	}

	if p.active > 0 {
		p.active--
	}
	client.is_active = false

	select {
		p.connections <- client {}
		else {
			client.close() or {}
		}
	}
}

pub fn (mut p Pool) close() {
	p.close = true
	for {
		select {
			mut client := <-p.connections {
				client.close() or {}
			}
			else {
				p.connections.close()
				break
			}
		}
	}
}
