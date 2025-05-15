# VRedis

VRedis is a Redis client service written in the V programming language. It allows you to connect to a Redis database over the network, send commands, and receive responses. Please note that this project is currently under **development** and is not recommended for use in production projects.

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/xiusin/vredis)


> Almost support all Redis commands.

# Installation

Before using VRedis, you will need to install the V programming language compiler. Please visit the [V language website](https://vlang.io) for installation instructions. Once you have installed the V compiler, you can install VRedis using the following command:

```vlang
v install xiusin.vredis
```

# Usage

Using VRedis is straightforward. First, you need to import the vredis module:


```vlang
import xiusin.vredis
```

Once you have successfully connected, you can send commands using the `send()` method and receive responses using the `recv()` method:

```vlang
redis := vredis.new_client(host: '127.0.0.1', port: 6379, db: 1, name: 'vclient', requirepass: '')

// or pool
mut pool := new_pool(
	dial: fn () !&Redis {
		return new_client()!
	}
	max_active: 2
	max_conn_life_time: 1
	test_on_borrow: fn (mut conn ActiveRedisConn) ! {
		conn.ping()!
	}
)

mut redis := pool.get()!
defer {
    redis.release() // You must execute this function, otherwise it will result in a memory leak.
}


redis.set("mykey", "hello")!
redis.keys('*')!
redis.del('mykey')!
redis.hset('website', 'api', 'api.vlang.io')!
redis.zadd('sets', 1, 'v1', '2', 'v2')!

// For more usage, please refer to the test cases.

redis.flushall()!
```

# Redis Pub/Sub Subscribe to Multiple Channels Example

This example demonstrates how to use the redis.psubscribe function in Redis to subscribe to multiple channels and receive messages that match specified patterns.
```v
redis.psubscribe(['chan*', 'order*', 'sms*'], fn (pattern string, chan string, message string) ! {
    println('pattern: ${pattern} 	chan: ${chan} -> message: ${message}')
})!

// You must use a new instance because the above instance is blocked.
redis1.publish('chan1', 'to chan1')!
redis1.publish('order1', 'to chan1')!
redis1.publish('sms1', 'to chan1')!
```


Finally, when you are finished with the connection, use the close() method to close it:

```vlang
redis.close()
// or
redis.release() // pool mode
```

# Contributing

If you are interested in VRedis and would like to contribute to it, feel free to submit issues or pull requests to our code repository on GitHub: https://github.com/xiusin/vredis

# License

VRedis is licensed under the MIT License. See the LICENSE file for more information.
