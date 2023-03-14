# VRedis

VRedis is a Redis client service written in the V programming language. It allows you to connect to a Redis database over the network, send commands, and receive responses. Please note that this project is currently under **development** and is not recommended for use in production projects.

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
client := vredis.new_client()
client.connect("127.0.0.1", 6379)
client.send("SET", "mykey", "hello")
res := client.recv()
println(res) // outputs "OK"
```

Finally, when you are finished with the connection, use the close() method to close it:

```vlang
client.close()
```

# Contributing

If you are interested in VRedis and would like to contribute to it, feel free to submit issues or pull requests to our code repository on GitHub: https://github.com/xiusin/vredis

# License

VRedis is licensed under the MIT License. See the LICENSE file for more information.
