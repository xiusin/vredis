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
	idle_conns     datatypes.LinkedList[ActiveRedisConn] = datatypes.LinkedList[ActiveRedisConn]{}
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
	p.mu.@lock()
	defer {
		p.mu.unlock()
	}
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
	defer {
		p.active--
		p.mu.unlock()
	}

	if p.close {
		return
	}



}

fn (mut p Pool) close() {
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
