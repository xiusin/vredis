module vredis

import os
import time

pub fn (mut r Redis) subscribe(channels []string, cb fn(string) ) ! {
	r.@lock()
	defer {
		r.unlock()
	}

	mut f := os.open_append('subscribe.log')!
	f.write_string("SUBSCRIBE ${channels.join(' ')}")!

	r.socket.write_string("SUBSCRIBE ${channels.join(' ')}")!
	r.socket.write_string("SUBSCRIBE ${channels.join(' ')}")!
	println( r.socket.read_line())
	time.sleep(time.second * 100)
	// line :=  r.socket.read_line()
	// f.write_string("订阅命令发送结束")!
	// f.close()
	// println(line)
	// f.write_string(line + "\r\n")!

		// str := r.socket.read_line()
		// f.write_string(str)!
		// cb(str)
}

pub fn (mut r Redis) publish(channel string, message string) !int {
	return r.send('PUBLISH', channel, message)!.int()
}
