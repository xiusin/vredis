module vredis

import os

pub fn (mut r Redis) subscribe(channels []string, cb fn (string)) ! {
	r.@lock()
	defer {
		r.unlock()
	}
	mut f := os.open_append('subscribe.log')!
	f.write_string('SUBSCRIBE ${channels.join(' ')} \r\n')!
	r.socket.write('SUBSCRIBE ${channels.join(' ')}'.bytes())!
	// for {
	// 	select {
	// 		ctx.done() {  }
	// 	}
	// 	cb(r.read_reply()!)
	// }
}

pub fn (mut r Redis) publish(channel string, message string) !int {
	return r.send('PUBLISH', channel, message)!.int()
}
