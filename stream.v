module vredis

import time


pub fn (mut r Redis) subscribe(channel string, channels... string) ! {
	r.@lock()
	defer {
		r.unlock()
	}

	mut all_chans := [channel]
	all_chans << channels

	spawn r.socket.write_string("SUBSCRIBE ${all_chans.join(' ')}")
	println('SUBSCRIBE ')
	for {
		println(r.socket.read_line())
		time.sleep(time.second)
	}

}
