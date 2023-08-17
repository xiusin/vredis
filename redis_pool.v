module vredis

import sync
import time

const err_pool_exhausted = error('vredis: connection pool exhausted')

const err_conn_closed = error('vredis: connection closed')

const err_conn_no_active = error('vredis: client no active')

type DialFn = fn () !&Redis

// PoolOpt Struct representing the options for a connection pool.
[params]
pub struct PoolOpt {
	dial               DialFn = unsafe { nil } // Function used to establish a connection.
	max_active         int    = 10 // Maximum number of active connections allowed in the pool.
	idle_timeout       i64    = 600 // Maximum time in seconds that an idle connection can stay in the pool.
	max_conn_life_time i64    = 600 // Maximum time in seconds that a connection can stay alive.
	test_on_borrow     fn (&ActiveRedisConn) ! = unsafe { nil } // Function used to test a connection before borrowing it from the pool.
}

pub struct Pool {
	sync.Once
mut:
	opt         PoolOpt
	close       bool
	connections chan &ActiveRedisConn
	mu          sync.Mutex
	active      u32
}

pub fn new_pool(opt PoolOpt) !&Pool {
	if isnil(opt.dial) {
		return error('invalid dial fn setting')
	}

	return &Pool{
		opt: opt
		connections: chan &ActiveRedisConn{cap: opt.max_active}
	}
}

fn (mut p Pool) str() string {
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}

	return '&vredis.Pool{
	active: ${p.active}
	len: ${p.connections.len}
	close: ${p.close}
	opt: ${p.opt}
}'
}

fn (mut p Pool) get() !&ActiveRedisConn {
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}

	if p.close {
		return vredis.err_conn_closed
	}

	if p.active >= p.opt.max_active { // 超出最大活动链接
		return vredis.err_pool_exhausted
	}

	for {
		select {
			mut client := <-p.connections {
				if time.now().unix - client.active_time >= p.opt.max_conn_life_time {
					client.close() or {}
					continue
				}

				if time.now().unix - client.put_in_time >= p.opt.idle_timeout {
					client.close() or {}
					continue
				}

				client.is_active = true

				if !isnil(p.opt.test_on_borrow) {
					p.opt.test_on_borrow(client) or {
						client.close() or {}
						continue
					}
				}

				return client
			}
			else {
				mut client := p.opt.dial()!
				p.active++
				return &ActiveRedisConn{
					active_time: time.now().unix
					pool: &p
					Redis: client
				}
			}
		}
	}

	return vredis.err_pool_exhausted
}

pub fn (mut p Pool) active_cnt() u32 {
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}

	return p.active
}

fn (mut p Pool) put(mut client ActiveRedisConn) {
	p.mu.@lock()
	defer {
		p.active--
		p.mu.unlock()
	}

	if p.close {
		return
	}

	if !client.is_active {
		return
	}
	client.is_active = false

	select {
		p.connections <- client {}
		else {
			client.close() or {}
		}
	}
}

fn (mut p Pool) close() {
	p.close = true
	for {
		select {
			mut client := <-p.connections {
				client.close() or {}
			}
			else {
				p.connections.close()
			}
		}
	}
}
