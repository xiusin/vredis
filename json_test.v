module vredis

struct JsonUser {
	name string
	age  int
}

fn test_json_set_get() ! {
	mut redis := new_client(db: 10)!
	defer {
		redis.close() or {}
	}

	assert redis.flushdb()!

	// Store a struct as JSON.
	u := JsonUser{name: 'alice', age: 30}
	assert redis.set_json('user:1', u)!

	// Retrieve and decode.
	got := redis.get_json[JsonUser]('user:1')!
	assert got.name == 'alice'
	assert got.age == 30

	// Missing key returns err_nil.
	nil_user := redis.get_json[JsonUser]('missing') or {
		assert err.msg() == 'redis: nil reply'
		JsonUser{}
	}
	assert nil_user.name == ''

	// Overwrite with a new value.
	assert redis.set_json('user:1', JsonUser{name: 'bob', age: 25})!
	got2 := redis.get_json[JsonUser]('user:1')!
	assert got2.name == 'bob'
	assert got2.age == 25

	// Corrupt JSON yields a decode error.
	assert redis.set('user:1', 'not json')!
	decode_failed := redis.get_json[JsonUser]('user:1') or {
		assert err.msg().starts_with('redis: json decode failed')
		JsonUser{name: 'decode_err', age: -1}
	}
	assert decode_failed.name == 'decode_err'
}

fn test_bool_arg() ! {
	mut redis := new_client(db: 10)!
	defer {
		redis.close() or {}
	}

	assert redis.flushdb()!

	// bool true → "1", bool false → "0" (Redis convention for bitmaps).
	// bool is accepted as a CmdArg in variadic position via send().
	assert redis.send('SET', 'bool_key', true)!.ok()
	assert redis.get('bool_key')! == '1'

	assert redis.send('SET', 'bool_key', false)!.ok()
	assert redis.get('bool_key')! == '0'
}
