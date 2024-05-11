module vredis

struct Reply {
mut:
	data []u8
}

const ok_flag = 'OK'

const crlf = '\r\n'

@[inline]
pub fn (r Reply) ok() bool {
	return r.@is(vredis.ok_flag)
}

@[inline]
pub fn (r Reply) int() int {
	return r.data.bytestr().int()
}

@[inline]
pub fn (r Reply) bytestr() string {
	return r.data.bytestr()
}

@[inline]
pub fn (r Reply) f64() f64 {
	return r.data.bytestr().f64()
}

@[inline]
pub fn (r Reply) i64() i64 {
	return r.data.bytestr().i64()
}

@[inline]
pub fn (r Reply) strings() []string {
	return r.data.bytestr().split(vredis.crlf)
}

@[inline]
pub fn (r Reply) @is[T](v T) bool {
	return r.data.bytestr() == v.str()
}

@[inline]
pub fn (r Reply) data() []u8 {
	return r.data
}
