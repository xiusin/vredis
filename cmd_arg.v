module vredis

import strings

// CmdArg is a sum type representing a single Redis command argument.
// Using a sum type lets callers pass strings, numeric values, and
// booleans without manual string conversion at every call site.
//
// For structured data (structs, maps, arrays), encode to JSON first and
// pass the resulting string — see Redis.set_json / get_json for a
// typed convenience wrapper.
pub type CmdArg = bool | f64 | i64 | int | string | u64

// CmdArgs is a growable list of command arguments that knows how to
// serialise itself into a RESP request.
pub type CmdArgs = []CmdArg

// to_str returns the canonical string form of a single argument. This
// is the value that gets length-prefixed in the RESP wire format.
@[inline]
fn (arg CmdArg) to_str() string {
	return match arg {
		string {
			arg
		}
		int {
			arg.str()
		}
		i64 {
			arg.str()
		}
		u64 {
			arg.str()
		}
		f64 {
			arg.str()
		}
		bool {
			if arg {
				'1'
			} else {
				'0'
			}
		}
	}
}

// add appends one or more arguments to the list.
pub fn (mut args CmdArgs) add(params ...CmdArg) {
	if params.len > 0 {
		args << params
	}
}

// int_str_len returns the number of decimal digits needed to represent
// a non-negative integer. Used for tight RESP wire-size estimation so
// the builder never reallocates.
@[inline]
fn int_str_len(n int) int {
	if n <= 0 {
		return 1
	}
	mut digits := 0
	mut v := n
	for v > 0 {
		v /= 10
		digits++
	}
	return digits
}

// estimate_wire_size computes the exact RESP wire size for a command
// name plus its arguments, given their pre-converted string forms.
// Layout per arg:  "$" + <len_digits> + "\r\n" + <payload> + "\r\n"
// Header:          "*" + <argc_digits> + "\r\n"
@[inline]
fn estimate_wire_size(argc int, strs []string) int {
	mut total := 1 + int_str_len(argc) + 2 // "*<n>\r\n"
	for s in strs {
		total += 1 + int_str_len(s.len) + 2 + s.len + 2
	}
	return total
}

// build_cmd serialises a command name plus variadic arguments into a
// RESP request string in a single pass.
//
// This is the hot-path entry point used by Redis.send(): it avoids the
// intermediate []CmdArg allocation that wrapping in CmdArgs would
// require. Each argument is converted to a string exactly once, the
// total wire size is computed from the converted strings, and a single
// pre-sized builder writes the entire request without reallocation.
pub fn build_cmd(cmd string, params ...CmdArg) string {
	argc := 1 + params.len

	// Convert all arguments to strings exactly once. For string args
	// to_str() is a no-op (returns the same string), so the only
	// allocation cost is for numeric args and the strs slice itself.
	mut strs := []string{cap: argc}
	strs << cmd
	for p in params {
		strs << p.to_str()
	}

	mut buf := strings.new_builder(estimate_wire_size(argc, strs))
	defer {
		unsafe {
			buf.free()
		}
	}

	buf.write_string('*')
	buf.write_string(argc.str())
	buf.write_string(crlf)

	for s in strs {
		buf.write_string('$')
		buf.write_string(s.len.str())
		buf.write_string(crlf)
		buf.write_string(s)
		buf.write_string(crlf)
	}

	return buf.str()
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
// Single-pass: each argument is converted to a string exactly once,
// the total wire size is computed from the converted strings, and a
// single pre-sized builder writes the entire request without
// reallocation. Prefer build_cmd() on the hot path to avoid the
// intermediate []CmdArg allocation.
pub fn (mut args CmdArgs) build() string {
	// Convert all arguments to strings exactly once.
	mut strs := []string{cap: args.len}
	for arg in args {
		strs << arg.to_str()
	}

	mut buf := strings.new_builder(estimate_wire_size(args.len, strs))
	defer {
		unsafe {
			buf.free()
		}
	}

	buf.write_string('*')
	buf.write_string(args.len.str())
	buf.write_string(crlf)

	for s in strs {
		buf.write_string('$')
		buf.write_string(s.len.str())
		buf.write_string(crlf)
		buf.write_string(s)
		buf.write_string(crlf)
	}

	return buf.str()
}
