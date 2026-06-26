module vredis

// subscribe subscribes to one or more channels and invokes cb for each
// received message. The call blocks until the connection is closed or
// an error occurs.
//
// On exit the connection automatically unsubscribes and restores the
// original read timeout.
pub fn (mut r Redis) subscribe(channels []string, cb fn (string, string) !) ! {
	r.subscribe_('SUBSCRIBE', channels, fn [cb] (reply &Reply) ! {
		// A "message" reply is: ["message", channel, payload]
		if reply.kind != .array || reply.arr.len < 3 {
			return
		}
		if reply.arr[0].str_val == 'message' {
			cb(reply.arr[1].str_val, reply.arr[2].str_val)!
		}
	})!
}

// psubscribe subscribes to one or more glob-style patterns and invokes
// cb for each matching message.
pub fn (mut r Redis) psubscribe(channels []string, cb fn (string, string, string) !) ! {
	r.subscribe_('PSUBSCRIBE', channels, fn [cb] (reply &Reply) ! {
		// A "pmessage" reply is: ["pmessage", pattern, channel, payload]
		if reply.kind != .array || reply.arr.len < 4 {
			return
		}
		if reply.arr[0].str_val == 'pmessage' {
			cb(reply.arr[1].str_val, reply.arr[2].str_val, reply.arr[3].str_val)!
		}
	})!
}

// subscribe_ is the low-level pub/sub loop. It sends the subscribe
// command, then repeatedly reads replies and passes them to cb.
//
// The callback receives a typed &Reply so callers can inspect the full
// structure of subscribe / message / unsubscribe replies.
//
// Concurrency: the Redis mutex is held for the entire duration of the
// subscription loop so that no other command interleaves with the
// message stream. On exit (error or normal return) the connection is
// unsubscribed and the read timeout is restored.
//
// Wire format: both the subscribe and unsubscribe commands are emitted
// as proper RESP arrays via build_cmd(), ensuring binary-safe channel
// names and full protocol compliance.
pub fn (mut r Redis) subscribe_(cmd string, channels []string, cb fn (&Reply) !) ! {
	// Convert channel names to CmdArg once — reused for both subscribe
	// and the unsubscribe that runs in the defer block.
	mut args := []CmdArg{cap: channels.len}
	for ch in channels {
		args << ch
	}

	r.@lock()

	// Save the current read timeout so we can restore it on exit.
	saved_read_timeout := r.socket.read_timeout()

	// Blocking read — no timeout while waiting for messages.
	r.socket.set_read_timeout(0)

	defer {
		// Restore timeout and unsubscribe. The mutex is still held here
		// (defers run before the function returns, and we unlock last).
		r.socket.set_read_timeout(saved_read_timeout)
		unsubscribe_cmd := if cmd == 'SUBSCRIBE' { 'UNSUBSCRIBE' } else { 'PUNSUBSCRIBE' }
		// Send unsubscribe directly via the socket — we cannot call
		// send() because it would try to re-lock the mutex we hold.
		// build_cmd() produces a proper RESP array, unlike the previous
		// inline-format concatenation which mixed command name with
		// RESP-encoded arguments.
		r.write_cmd(build_cmd(unsubscribe_cmd, ...args)) or {}
		r.unlock()
	}

	// Send the subscribe command as a proper RESP array.
	r.write_cmd(build_cmd(cmd, ...args))!

	// Message loop — exits when read_reply returns an error (e.g. the
	// socket is closed) or when cb returns an error.
	for {
		reply := r.protocol.read_reply() or { break }
		cb(reply) or { break }
	}
}

@[inline]
pub fn (mut r Redis) publish(channel string, message string) !int {
	return r.send('PUBLISH', channel, message)!.int()
}

pub fn (mut r Redis) pubsub(subcommand string, arguments ...string) !string {
	mut args := []CmdArg{cap: 1 + arguments.len}
	args << subcommand
	for arg in arguments {
		args << arg
	}
	return r.send('PUBSUB', ...args)!.bytestr()
}
