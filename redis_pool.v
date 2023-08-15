module vredis

import sync
import time

const err_pool_exhausted = error('vredis: connection pool exhausted')

const err_conn_closed = error('vredis: connection closed')

const err_conn_no_active = error('vredis: client no active')

type DialFn = fn () !&Redis

[params]
pub struct PoolOpt {
	dial               DialFn = unsafe { nil } // 拨号函数
	max_active         int    = 10 // 最大活动链接数
	idle_timeout       i64    = 600 // 最大空闲时间
	max_conn_life_time i64    = 600 // 最大链接时间
	test_on_borrow     fn (&ActiveRedisConn) ! = unsafe { nil } // 借用时测试函数
}

pub struct Pool {
	sync.Once
mut:
	opt           PoolOpt
	close         bool // 是否已关闭
	connections   chan &ActiveRedisConn
	mu            sync.Mutex // 锁
	active        u32        // 当前活动数量
	wait_count    i64        //等待数
	wait_duration i64        // 等待时长
}

pub fn new_pool(opt PoolOpt) &Pool {
	return &Pool{
		opt: opt
		close: false
		connections: chan &ActiveRedisConn{cap: opt.max_active}
		active: 0
	}
}

// str 字符串输出对象
fn (mut p Pool) str() string {
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}
	return 'vredis.Pool{active: ${p.active}}'
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

	println('p.connections.len = ${p.connections.len}')

	for {
		select {
			mut client := <-p.connections {
				if time.now().unix - client.active_time >= p.opt.max_conn_life_time { // 生存周期超出则销毁此对象
					println('life time kill')
					client.close() or {}
					continue
				}

				if time.now().unix - client.put_in_time >= p.opt.idle_timeout { // 空闲时间过长
					println('idle time kill')
					client.close() or {}
					continue
				}

				client.is_active = true

				if !isnil(p.opt.test_on_borrow) {
					p.opt.test_on_borrow(client) or { // 测试对象失败,则销毁
						client.close() or {}
						println('test_on_borrow kill')
						continue
					}
				}

				return client
			} // 弹出一个对象
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
	p.connections.close()
}
