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

fn (mut p Protocol) read_reply(is_sub ...bool) ![]u8 {
	mut data := p.client.socket.read_line().bytes()

	println('<- ${data.bytestr()}')

	// only top read delete
	if is_sub.len == 0 || !is_sub[0] {
		data.delete_last()
		data.delete_last()
	}


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

			mut multi_str_len := data[1..].bytestr().int()
			mut byts := []u8{cap: multi_str_len}

			// 读取接下来的字节数,需要等于本次返回长度
			for multi_str_len > byts.len {
				byts << p.read_reply(true)!
			}

			// EOF
			if multi_str_len >= 2 {
				byts.delete_last()
				byts.delete_last()
			}

			return byts
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
