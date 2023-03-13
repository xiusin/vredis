module vredis

pub fn (mut r Redis) sadd(key string, member string, members... string) {

}

pub fn (mut r Redis) scard(key string) {

}


pub fn (mut r Redis) sdiff(key string, keys... string) {

}

pub fn (mut r Redis) sdiffstore(key string,  keys... string) {

}


pub fn (mut r Redis) sinter(key string, keys... string) {

}

pub fn (mut r Redis) sinterstore(key string, keys... string) {

}

pub fn (mut r Redis) sismember (key string, value string) bool {

}

pub fn (mut r Redis) smove (source string, destination string, member string) bool {

}

pub fn (mut r Redis) spop (key string) bool {

}

pub fn (mut r Redis) srandmember(key string, cnt... int) bool {

}

pub fn (mut r Redis) srem (key string, member string, members ... string) bool {

}

pub fn (mut r Redis) sunion(key string, keys... string) {

}

pub fn (mut r Redis) sunionstore(key string, keys... string) {

}

pub fn (mut r Redis) sscan(key string, cursor i64, pattern string, count i64 ) {

}


