module vredis

pub fn (mut r Redis) eval(script string, num_keys int, keys_and_args ...string) !string {
	if keys_and_args.len < num_keys {
		return error('keys_and_args.len != ${num_keys}')
	}
	mut args := [CmdArg(script), CmdArg(num_keys)]
	for it in keys_and_args {
		args << it
	}

	return r.send('EVAL', ...args)!.trim_right('\r\n')
}

pub fn (mut r Redis) evalsha(sha1 string, num_keys int, keys_and_args ...string )!string {
	if keys_and_args.len < num_keys {
		return error('keys_and_args.len != ${num_keys}')
	}

	mut args := [CmdArg(sha1), CmdArg(num_keys)]
	for it in keys_and_args {
		args << it
	}
	line := r.send('EVALSHA', ...args)!.trim_right('\r\n')
	return line
}

pub fn (mut r Redis) script_load(script string) !string {
	return r.send('SCRIPT', 'LOAD', script)!.trim_right('\r\n')
}

pub fn (mut r Redis) script_kill() !bool {
	return r.send('SCRIPT', 'KILL')!.starts_with(ok_flag)
}

pub fn (mut r Redis) script_flush() !bool {
	return r.send('SCRIPT', ' FLUSH')!.starts_with(ok_flag)
}

pub fn (mut r Redis) script_exists(sha string, shas ...string) !map[string]bool {
	mut args := [CmdArg('EXISTS'), CmdArg(sha)]
	for it in shas {
		args << it
	}

	res_arr := r.send('SCRIPT', ...args)!.split('\r\n')
	mut result := map[string]bool{}
	for i := 1; i < args.len; i++ {
		result[args[i] as string] = res_arr[i].u8() == 1
	}
	return result
}
