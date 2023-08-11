module vredis

[params]
pub struct ScriptOpts {
	keys []string
	args []string
}

pub fn (mut r Redis) eval(script string, num_keys int, keys_and_args ...string) !string {
	if keys_and_args.len < num_keys {
		return error('keys_and_args.len != ${num_keys}')
	}
	line := r.send('EVAL "${script}" ${num_keys} ${keys_and_args.join(' ')}')!.trim_right('\r\n')
	return line
}

pub fn (mut r Redis) evalsha(sha1 string, num_keys int, keys_and_args ...string )!string {
	if keys_and_args.len < num_keys {
		return error('keys_and_args.len != ${num_keys}')
	}
	line := r.send('EVALSHA "${sha1}" ${num_keys} ${keys_and_args.join(' ')}')!.trim_right('\r\n')
	return line
}

pub fn (mut r Redis) script(cmd string, scripts ...string) bool {
	line := r.send('EVAL "${cmd}" ${scripts.join(' ')}') or { ':0' }

	println('line => ${line}')
	return true
}

pub fn (mut r Redis) script_load(script string) !string {
	return r.send('SCRIPT LOAD "${script}"')!.trim_right('\r\n')
}

pub fn (mut r Redis) script_kill() bool {
	res := r.send('SCRIPT KILL') or { ':0' }
	return res.starts_with('+OK')
}

pub fn (mut r Redis) script_flush() bool {
	res := r.send('SCRIPT FLUSH') or { ':0' }
	return res.starts_with('+OK')
}

pub fn (mut r Redis) script_exists(sha string, shas ...string) map[string]bool {
	mut sha_arr := [sha]
	sha_arr << shas
	res := r.send('SCRIPT EXISTS ${sha_arr.join(' ')}') or { '' }
	res_arr := res.split('\r\n')
	mut result := map[string]bool{}
	for i := 0; i < sha_arr.len; i++ {
		result[sha_arr[i]] = res_arr[i][1..].u8() == 1
	}
	return result
}
