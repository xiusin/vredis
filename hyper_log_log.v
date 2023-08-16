module vredis

pub fn (mut r Redis) pfadd(key string, element string, elements ...string) !int {
	mut args := [CmdArg(element)]
	for it in elements {
		args << it
	}
	return r.send('PFADD', ...args)!.int()
}

pub fn (mut r Redis) pfcount(key string) !int {
	return r.send('PFCOUNT', key)!.int()
}

pub fn (mut r Redis) pfmerge(destkey string, sourcekey string, sourcekeys ...string) !bool {
	mut args := [CmdArg(destkey), CmdArg(sourcekey)]
	for it in sourcekeys {
		args << it
	}

	return r.send('PFMERGE', ...args)!.ok()
}
