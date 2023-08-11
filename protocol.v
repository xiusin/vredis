module vredis

pub struct Protocol {
mut:
	client &Redis = unsafe { nil }
}

fn new_protocol(client &Redis) &Protocol {
	return &Protocol{
		client: unsafe { client }
	}
}

fn (mut p Protocol) read_reply() ![]u8 {
	mut data := p.client.socket.read_line().bytes()

	println('<- ${data.bytestr()}')

	data.delete_last()
	data.delete_last()

	match data[0..1].bytestr() {
		'-' { // error
			return error(data[1..].bytestr())
		}
		'+', ':' { // simple string
			return data[1..]
		}
		'$' { // multi string
			if data.len == 3 && data.bytestr() == '$-1' {
				return '(nil)'.bytes()
			}

			// 向下读取一行
			return p.read_reply()!
		}
		'*' { // array
			line_num := data[1..].bytestr().int()
			if line_num == -1 {
				return '(nil)'.bytes()
			}
			data.clear()
			for i := 0; i < line_num; i++ {
				if i > 0 {
					data << '\r\n'.bytes()
				}
				data << p.read_reply()!
			}
			return data
		}
		else {
			return data
		}
	}
}
