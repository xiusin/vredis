module vredis

// 命令化, 方便处理返回值问题
interface IRedisCmd {
	cmd string
	resp []u8

	clean_flag()


}


pub struct NumericCmd {
	cmd string
	resp []u8
}

fn (n &NumericCmd) clean_flag() {
	panic('not implemented')
}
