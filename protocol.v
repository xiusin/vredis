module vredis

import strings

// Protocol is a RESP (REdis Serialization Protocol) reader bound to a
// single Redis connection.
//
// Design notes
// ------------
// The previous implementation read every reply with `read_line()` and
// joined array elements with "\r\n". This corrupted any payload
// containing those bytes and made nested arrays impossible to parse
// correctly.
//
// This implementation follows the RESP specification exactly:
//   - Status  (+)  and error (-) replies are read line-by-line.
//   - Integer (:)  replies are parsed from the line payload.
//   - Bulk    ($)  replies read exactly N bytes after the length header,
//                  then consume the trailing CRLF. This is binary-safe.
//   - Array   (*)  replies recursively read N sub-replies.
//   - Null    ($-1 / *-1) replies become a Reply with kind == .nil_reply.
//
// A reusable stack buffer is used for chunked bulk reads to avoid
// per-command heap allocation on the hot path.
pub struct Protocol {
mut:
	client &Redis = unsafe { nil }
}

fn new_protocol(client &Redis) &Protocol {
	return &Protocol{
		client: unsafe { client }
	}
}

// read_line reads one CRLF-terminated line from the socket and returns
// the payload without the trailing CR/LF. `read_line()` on TcpConn
// returns content up to and including LF, so we trim the trailing
// CR/LF pair. An empty result signals EOF / closed connection.
@[inline]
fn (mut p Protocol) read_line() !string {
	line := p.client.socket.read_line()
	if line.len == 0 {
		return err_read_message
	}
	// read_line() includes the trailing \n; RESP lines end with \r\n.
	// Trim any trailing \r and \n characters.
	return line.trim_right('\r\n')
}

// read_full reads exactly `need` bytes from the socket into a freshly
// allocated, owned string. A stack scratch buffer is reused across
// calls to avoid per-read heap allocation. The trailing CRLF that
// follows every bulk payload is consumed and discarded.
//
// The caller must pass a non-negative length; nil bulks ($-1) are
// handled by read_reply before reaching this method.
fn (mut p Protocol) read_full(need int) !string {
	if need == 0 {
		// Consume the trailing CRLF of an empty bulk string.
		p.client.socket.read_line()
		return ''
	}

	mut builder := strings.new_builder(need)
	defer {
		unsafe {
			builder.free()
		}
	}
	mut scratch := [4096]u8{}
	mut got := 0
	for got < need {
		remaining := need - got
		to_read := if remaining < scratch.len { remaining } else { scratch.len }
		n := unsafe {
			p.client.socket.read_ptr(&scratch[0], to_read)!
		}
		if n <= 0 {
			return err_read_message
		}
		unsafe {
			builder.write_ptr(&scratch[0], n)
		}
		got += n
	}
	// Consume the trailing \r\n that follows the bulk payload.
	p.client.socket.read_line()
	return builder.str()
}

// read_reply parses one complete RESP reply and returns a typed Reply.
pub fn (mut p Protocol) read_reply() !Reply {
	line := p.read_line()!
	if line.len == 0 {
		return err_read_message
	}

	if p.client.debug {
		println('<- ${line}')
	}

	first := line[0]
	payload := line[1..]

	match first {
		`-` {
			// Error reply: the payload is the error message.
			return Reply{
				kind:    .error
				str_val: payload
			}
		}
		`+` {
			// Simple status string.
			return Reply{
				kind:    .status
				str_val: payload
			}
		}
		`:` {
			// Integer reply.
			return Reply{
				kind:    .integer
				int_val: payload.i64()
			}
		}
		`$` {
			// Bulk string. $-1 means nil.
			n := payload.i64()
			if n < 0 {
				return Reply{
					kind: .nil_reply
				}
			}
			data := p.read_full(int(n))!
			return Reply{
				kind:    .bulk
				str_val: data
			}
		}
		`*` {
			// Array. *-1 means nil array.
			count := payload.i64()
			if count < 0 {
				return Reply{
					kind: .nil_reply
				}
			}
			mut elems := []Reply{cap: int(count)}
			for _ in 0 .. count {
				elems << p.read_reply()!
			}
			return Reply{
				kind: .array
				arr:  elems
			}
		}
		else {
			// Inline / unexpected payload — return as a bulk string
			// so callers that sent inline commands still get data.
			return Reply{
				kind:    .bulk
				str_val: line
			}
		}
	}
}
