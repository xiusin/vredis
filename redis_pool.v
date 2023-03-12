module vredis

import sync
import time
import context
import datatypes
import strconv

type DialFn = fn () !Redis

pub struct Pool {
	sync.Once
	test_on_borrow fn (Redis, time.Time) !
pub:
	dial               DialFn
	max_idle           u32
	max_active         int
	idle_timeout       i64
	max_conn_life_time i64
	wait               bool
	close              bool
mut:
	ch            chan bool
	mu            sync.Mutex
	idle          u32
	active        u32
	wait_count    i64
	wait_duration i64
	idle_conn     datatypes.LinkedList[ActiveRedisConn] = datatypes.LinkedList[ActiveRedisConn]{}
}

fn (mut p Pool) str() string {
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}
	return strconv.v_sprintf(r'vredis.Pool{
	active: %d
}', p.active)
}

fn (mut p Pool) get() !ActiveRedisConn {
	return p.get_context(context.background())
}

fn (mut p Pool) get_context(ctx context.Context) !ActiveRedisConn {
	// waited := p.wait_vacant_conn(ctx)!
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}

	// if waited > 0 {
	// 	p.wait_count++
	// 	p.wait_duration+= waited
	// }
	// 剔除空闲超出时间的链接
	// if p.idle_timeout > 0 {
	// 	idle_len := p.idle_conn.len()
	// 	for client in p.idle_conn.iterator() {
	// 		if client.active_time + p.idle_conn.
	// 	}
	mut client := p.dial()!
	p.active++
	return ActiveRedisConn{
		active_time: time.now().unix
		pool: &p
		Redis: client
	}
}

pub fn (mut p Pool) active_cnt() u32 {
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}

	return p.active
}

pub fn (mut p Pool) idle_cnt() u32 {
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}

	return p.idle
}

fn (mut p Pool) put() {
	p.mu.@lock()
}

fn (mut p Pool) lazy_init() {
	p.do(fn [mut p] () {
		p.ch = chan bool{cap: p.max_active}
		if p.close {
			p.ch.close()
		} else {
			for i := 0; i < p.max_active; i++ {
				p.ch <- true
			}
		}
	})
}

// wait_vacant_conn 等待空闲
// fn (mut p Pool) wait_vacant_conn(ctx context.Context) !time.Duration {
// 	if !p.wait || p.max_active == 0 {
// 		return 0
// 	}
// 	p.lazy_init()
// 	// wait := p.ch.len() == 0
// 	// if wait {
// 	// 	start = time.now()
// 	// }
// }
