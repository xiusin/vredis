module vredis

pub fn (mut r Redis) xadd(key string, id string, field string, value string, field_values ...string) !string {
	mut args := [CmdArg(key), CmdArg(id), CmdArg(field), CmdArg(value)]
	for it in field_values {
		args << it
	}

	return r.send('XADD', ...args)!
}

pub fn (mut r Redis) xdel(key string, id string, ids ...string) !int {
	mut args := [CmdArg(key), CmdArg(id)]
	for it in ids {
		args << it
	}

	return r.send('XDEL', ...args)!.int()
}

pub fn (mut r Redis) xlen(key string) !int {
	return r.send('XLEN', key)!.int()
}

pub fn (mut r Redis) xtrim(key string,count int, same ...bool) !int {
	mut args := [CmdArg(key), CmdArg('MAXLEN')]

	if same.len > 0 && same[0] {
		args << "~"
	}
	args << count
	return r.send('XTRIM', ...args)!.int()
}
