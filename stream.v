module vredis

import os
import time


pub fn (mut r Redis) subscribe(channel string, channels... string) ! {
	r.@lock()
	defer {
		r.unlock()
	}

	mut all_chans := [channel]
	all_chans << channels

	// 起一个协程
	spawn r.socket.write_string("SUBSCRIBE ${all_chans.join(' ')}")!

	for {
		os.write_file('pubsub.log', r.socket.read_line())!
		time.sleep(time.minute)
	}



}
