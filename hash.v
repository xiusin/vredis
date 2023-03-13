module vredis

fn (mut r Redis) hdel(key string, field string, fields ...string) bool {
	mut keys := [field]
	keys << fields
	res := r.send_cmd('HDEL ${key} ${keys.join(' ')}') or { return false }
	return res != ':0'
}

fn (mut r Redis) hexists(key string, field string) bool {
	res := r.send_cmd('HEXISTS ${key} ${field}') or { return false }
	return res == ':1'
}

fn (mut r Redis) hget(key string, field string) !string {
	return r.send_cmd('HGET ${key} ${field}')!
}
//
// fn (mut r Redis) hgetall() {
// }

fn (mut r Redis) hset(key string, field string, value string) bool {
	res := r.send_cmd('HSET ${key} ${field} "${value}"') or { return false }
	return res in [':1', ':0']
}

fn (mut r Redis) hkeys(key string) []string {
	res := r.send_cmd('HKEYS ${key}') or { return [] }
	return res.split('\r\n')
}

fn (mut r Redis) hlen(key string) int {
	res := r.send_cmd('HLEN ${key}') or { return 0 }
	return res[1..].int()
}
