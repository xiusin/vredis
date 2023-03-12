module vredis

pub struct ActiveRedisConn {
	Redis
	active_time i64
mut:
	pool &Pool
}

pub fn (mut c ActiveRedisConn) close()! {
	c.pool.active--
	c.socket.close()!
}
