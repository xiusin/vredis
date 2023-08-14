module vredis

import strings

type CmdArg = f64 | i64 | int | string | u64

type CmdArgs = []CmdArg

pub fn (mut arg CmdArg) safe() CmdArg {
	mut cmd_arg_str := ''
	if arg is string {
		cmd_arg_str = arg as string
		cmd_arg_str = cmd_arg_str.replace('\r', '\\r')
		cmd_arg_str = cmd_arg_str.replace('\n', '\\n')
		cmd_arg_str = cmd_arg_str.replace('"', '\\"')
		cmd_arg_str = '"${cmd_arg_str}"'
	} else if arg is int {
		cmd_arg_str = (arg as int).str()
	} else if arg is i64 {
		cmd_arg_str = (arg as i64).str()
	} else if arg is f64 {
		cmd_arg_str = (arg as f64).str()
	} else if arg is u64 {
		cmd_arg_str = (arg as u64).str()
	} else {
		cmd_arg_str = arg.str().trim_string_left("vredis.CmdArgs(").trim_right(")")
	}
	return cmd_arg_str
}

pub fn (mut args CmdArgs) add(params ...CmdArg) {
	if params.len > 0 {
		args << params
	}
}

pub fn (mut args CmdArgs) build() string {
	mut len := 0
	for i, mut arg in args {
		arg = arg.safe()
		len += (arg as string).len
		args[i] = arg
	}
	mut buf := strings.new_builder(len + args.len + 2)
	for mut arg in args {
		buf.write_string(arg as string)
		buf.write_string(' ')
	}
	buf.delete_last()
	buf.write_string('\r\n')
	return buf.str()
}
