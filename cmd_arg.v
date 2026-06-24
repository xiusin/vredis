module vredis

import strings

// CmdArg is a sum type representing a single Redis command argument.
// Using a sum type lets callers pass strings and numeric values without
// manual string conversion at every call site.
pub type CmdArg = f64 | i64 | int | string | u64

// CmdArgs is a growable list of command arguments that knows how to
// serialise itself into a RESP request.
pub type CmdArgs = []CmdArg

// to_str returns the canonical string form of a single argument. This
// is the value that gets length-prefixed in the RESP wire format.
@[inline]
fn (arg CmdArg) to_str() string {
	match arg {
		string {
			return arg
		}
		int {
			return arg.str()
		}
		i64 {
			return arg.str()
		}
		u64 {
			return arg.str()
		}
		f64 {
			return arg.str()
		}
	}
}

// add appends one or more arguments to the list.
pub fn (mut args CmdArgs) add(params ...CmdArg) {
	if params.len > 0 {
		args << params
	}
}

// build serialises the argument list into a RESP request string.
//
// The previous implementation used the fragile inline command format
// (`SET key value\r\n`) which cannot carry binary data or values
// containing CR/LF. This implementation emits a proper RESP array:
//
//	*<argc>\r\n
//	$<len>\r\n<bytes>\r\n
//	...
//
// A single capacity estimate avoids regrowth of the builder, and each
// argument is converted to a string exactly once.
pub fn (mut args CmdArgs) build() string {
	// Pre-compute the total wire size so the builder never reallocates.
	// Overhead per arg: "$" + digits(len) + crlf + crlf  ≈ 24 bytes worst case.
	mut total := 4 // "*<n>\r\n"
	for arg in args {
		total += arg.to_str().len + 24
	}

	mut buf := strings.new_builder(total)
	defer {
		unsafe {
			buf.free()
		}
	}

	buf.write_string('*')
	buf.write_string(args.len.str())
	buf.write_string(crlf)

	for arg in args {
		s := arg.to_str()
		buf.write_string('$')
		buf.write_string(s.len.str())
		buf.write_string(crlf)
		buf.write_string(s)
		buf.write_string(crlf)
	}

	return buf.str()
}
