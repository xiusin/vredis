module vredis

// ReplyKind enumerates the RESP reply types returned by a Redis server.
pub enum ReplyKind {
	status    // +OK\r\n — simple status string
	error     // -ERR ...\r\n — error reply
	integer   // :123\r\n — 64-bit signed integer
	bulk      // $N\r\n<bytes>\r\n — bulk string (binary safe)
	array     // *N\r\n... — nested array of replies
	nil_reply // $-1\r\n or *-1\r\n — null bulk / null array
}

// Reply is a typed, parsed representation of a single Redis RESP reply.
//
// The previous implementation stored every reply as a raw []u8 and joined
// array elements with "\r\n", which corrupted any payload containing those
// bytes. This typed representation preserves structure and avoids repeated
// string conversions.
pub struct Reply {
pub:
	kind    ReplyKind
	str_val string  // payload for status / bulk / error-message
	int_val i64     // payload for integer replies
	arr     []Reply // payload for array replies (values stored inline)
}

const ok_flag = 'OK'

const nil_flag = '(nil)'

const crlf = '\r\n'

// ok reports whether the reply is a simple-status "OK".
@[inline]
pub fn (r Reply) ok() bool {
	return r.kind == .status && r.str_val == ok_flag
}

// nil reports whether the reply is a Redis null (bulk or array).
@[inline]
pub fn (r Reply) nil() bool {
	return r.kind == .nil_reply
}

// str returns the canonical string representation of the reply payload.
// For integer replies this is the decimal text; for nil it is "(nil)";
// otherwise it is the raw string payload. This is the single source of
// truth used by bytestr/is/data so conversions happen at most once per
// conceptual access.
@[inline]
pub fn (r Reply) str() string {
	return match r.kind {
		.integer { r.int_val.str() }
		.nil_reply { nil_flag }
		else { r.str_val }
	}
}

// bytestr is kept for backwards compatibility; it returns the same value
// as str().
@[inline]
pub fn (r Reply) bytestr() string {
	return r.str()
}

// int returns the reply payload as a V int.
@[inline]
pub fn (r Reply) int() int {
	if r.kind == .integer {
		return int(r.int_val)
	}
	return r.str_val.int()
}

// i64 returns the reply payload as an i64.
@[inline]
pub fn (r Reply) i64() i64 {
	if r.kind == .integer {
		return r.int_val
	}
	return r.str_val.i64()
}

// f64 returns the reply payload as an f64.
@[inline]
pub fn (r Reply) f64() f64 {
	if r.kind == .integer {
		return f64(r.int_val)
	}
	return r.str_val.f64()
}

// strings returns the string elements of an array reply. For non-array
// replies a single-element slice containing str() is returned.
pub fn (r Reply) strings() []string {
	if r.kind == .array {
		mut out := []string{cap: r.arr.len}
		for elem in r.arr {
			out << elem.str()
		}
		return out
	}
	return [r.str()]
}

// array returns the nested reply elements for array replies.
@[inline]
pub fn (r Reply) array() []Reply {
	return r.arr
}

// is compares the reply payload with v using string equality. This
// generic form keeps the ergonomic `reply.is(1)` / `reply.is('PONG')`
// call sites working regardless of the integer/string reply kind.
// `is` is a V keyword, so the method name is escaped with `@`.
@[inline]
pub fn (r Reply) @is[T](v T) bool {
	return r.str() == v.str()
}

// data returns the raw bytes of str(). It is kept for backwards
// compatibility with callers that previously operated on []u8.
@[inline]
pub fn (r Reply) data() []u8 {
	return r.str().bytes()
}
