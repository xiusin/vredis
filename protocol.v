module protocol

import vredis.vredis



pub struct Protocol {
mut:
	client &vredis.Redis

}

fn new(client &vredis.Redis) &Protocol {
	protocol := &Protocol{
		client: client
	}

	return protocol
}

fn (p &Protocol) read_reply() {
	p.client.@lock()
	defer {
		p.client.unlock()
	}

	p.client.r



}




