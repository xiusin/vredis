module vredis

pub fn (mut r Redis) subscribe(channel string, channels... string) ! {
	panic(error('no support'))
	// r.@lock()
	// defer {
	// 	r.unlock()
	// }
	// mut f := os.open_append('subscribe.log')!
	// defer {
	// 	f.close()
	// }
	// mut all_chans := [channel]
	// all_chans << channels
	// r.socket.write_string("SUBSCRIBE ${all_chans.join(' ')}")!
	// line :=  r.socket.read_line()
	// f.write_string(line + "\r\n")!
}

pub fn (mut r Redis) publish(channel string, message string) int {
	res := r.send('PUBLISH ${channel} "${message}"') or { return 0 }
	return res[1..].int()
}
