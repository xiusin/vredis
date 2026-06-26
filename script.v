module vredis

// eval executes a Lua script with the given keys and arguments.
// Returns the raw Reply so callers can handle any return type
// (integer, string, array, nil) that the script may produce.
pub fn (mut r Redis) eval(script string, num_keys int, keys_and_args ...string) !&Reply {
	if keys_and_args.len < num_keys {
		return error('keys_and_args.len != ${num_keys}')
	}
	mut args := []CmdArg{cap: 2 + keys_and_args.len}
	args << script
	args << num_keys
	for it in keys_and_args {
		args << it
	}
	return r.send('EVAL', ...args)
}

// evalsha executes a cached Lua script identified by its SHA1 digest.
// Returns the raw Reply for the same reason as eval().
pub fn (mut r Redis) evalsha(sha1 string, num_keys int, keys_and_args ...string) !&Reply {
	if keys_and_args.len < num_keys {
		return error('keys_and_args.len != ${num_keys}')
	}
	mut args := []CmdArg{cap: 2 + keys_and_args.len}
	args << sha1
	args << num_keys
	for it in keys_and_args {
		args << it
	}
	return r.send('EVALSHA', ...args)
}

@[inline]
pub fn (mut r Redis) script_load(script string) !string {
	return r.send('SCRIPT', 'LOAD', script)!.bytestr()
}

@[inline]
pub fn (mut r Redis) script_kill() !bool {
	return r.send('SCRIPT', 'KILL')!.ok()
}

// script_flush flushes the Lua script cache.
// Bug fix: the previous implementation sent ' FLUSH' (with a leading
// space) which Redis did not recognise.
@[inline]
pub fn (mut r Redis) script_flush() !bool {
	return r.send('SCRIPT', 'FLUSH')!.ok()
}

// script_exists checks whether one or more script SHA1 digests are
// present in the script cache. Returns a map of sha→present.
pub fn (mut r Redis) script_exists(sha string, shas ...string) !map[string]bool {
	mut args := [CmdArg('EXISTS'), CmdArg(sha)]
	for it in shas {
		args << it
	}

	res_arr := r.send('SCRIPT', ...args)!.strings()
	mut result := map[string]bool{}
	// args[0] is 'EXISTS'; args[1..] are the SHAs.
	for i := 1; i < args.len; i++ {
		result[args[i] as string] = res_arr[i - 1] == '1'
	}
	return result
}
