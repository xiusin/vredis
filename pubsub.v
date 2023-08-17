module vredis

fn (mut r Redis) subscribe(channels []string, cb fn (string, string) !) ! {
	r.subscribe_('SUBSCRIBE', channels, fn [cb] (it []u8) ! {
		content := it.bytestr()
		if content.starts_with('message') {
			ch, message := content.replace('message${crlf}', '').split_once(crlf) or {
				return error('read error')
			}
			cb(ch, message)!
		}
	})!
}

fn (mut r Redis) psubscribe(channels []string, cb fn (string, string, string) !) ! {
	r.subscribe_('PSUBSCRIBE', channels, fn [cb] (it []u8) ! {
		content := it.bytestr()
		if content.starts_with('pmessage') {
			pattern, reply := content.replace('pmessage${crlf}', '').split_once(crlf) or {
				return error('read error')
			}
			ch, message := reply.split_once(crlf) or { return error('read error') }
			cb(pattern, ch, message)!
		}
	})!
}

fn (mut r Redis) subscribe_(cmd string, channels []string, cb fn ([]u8) !) ! {
	mut args := []CmdArg{}
	for ch in channels {
		args << ch
	}
	mut cmd_args := CmdArgs(args)

	r.@lock()
	defer {
		r.unlock()
		unsubscribe_cmd := if cmd == 'SUBSCRIBE' { 'UNSUBSCRIBE' } else { 'PUNSUBSCRIBE' }
		r.send(unsubscribe_cmd, ...args) or {}
	}

	r.socket.set_read_timeout(0)
	r.write_string_to_socket('${cmd} ${cmd_args.build()}')!
	for {
		cb(r.protocol.read_reply()!)!
	}
}

pub fn (mut r Redis) publish(channel string, message string) !int {
	return r.send('PUBLISH', channel, message)!.int()
}

pub fn (mut r Redis) pubsub(subcommand string, arguments ...string) !string {
	mut args := [CmdArg(subcommand)]
	for arg in arguments {
		args << arg
	}
	return r.send('PUBSUB', ...args)!.bytestr()
}
