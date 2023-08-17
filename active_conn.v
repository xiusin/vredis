module vredis

import time

pub struct ActiveRedisConn {
	Redis
	active_time i64
mut:
	pool        &Pool
	put_in_time i64
}

pub fn (mut c ActiveRedisConn) release() {
	c.put_in_time = time.now().unix
	c.pool.put(mut c)
}
