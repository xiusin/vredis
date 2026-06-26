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
	u := JsonUser{
		name: 'alice'
		age:  30
	}
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
	assert redis.set_json('user:1', JsonUser{ name: 'bob', age: 25 })!
	got2 := redis.get_json[JsonUser]('user:1')!
	assert got2.name == 'bob'
	assert got2.age == 25

	// Corrupt JSON yields a decode error.
	assert redis.set('user:1', 'not json')!
	decode_failed := redis.get_json[JsonUser]('user:1') or {
		assert err.msg().starts_with('redis: json decode failed')
		JsonUser{
			name: 'decode_err'
			age:  -1
		}
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

fn test_json_map() ! {
	mut redis := new_client(db: 10)!
	defer {
		redis.close() or {}
	}

	assert redis.flushdb()!

	// map[string]int via set_json/get_json.
	assert redis.set_json('config', {
		'a': 1
		'b': 2
	})!
	m := redis.get_json[map[string]int]('config')!
	assert m['a'] == 1
	assert m['b'] == 2

	// map[string]string.
	assert redis.set_json('labels', {
		'env':  'prod'
		'team': 'core'
	})!
	labels := redis.get_json[map[string]string]('labels')!
	assert labels['env'] == 'prod'
	assert labels['team'] == 'core'
}

fn test_json_hash() ! {
	mut redis := new_client(db: 10)!
	defer {
		redis.close() or {}
	}

	assert redis.flushdb()!

	// Store structs as hash fields — one field per object.
	assert redis.hset_json('users', 'u1', JsonUser{ name: 'alice', age: 30 })!
	assert redis.hset_json('users', 'u2', JsonUser{ name: 'bob', age: 25 })!

	u1 := redis.hget_json[JsonUser]('users', 'u1')!
	assert u1.name == 'alice'
	assert u1.age == 30

	u2 := redis.hget_json[JsonUser]('users', 'u2')!
	assert u2.name == 'bob'
	assert u2.age == 25

	// Missing field returns err_nil.
	nil_u := redis.hget_json[JsonUser]('users', 'missing') or {
		assert err.msg() == 'redis: nil reply'
		JsonUser{}
	}
	assert nil_u.name == ''

	// Corrupt JSON yields a decode error.
	assert redis.hset('users', 'bad', 'not json')!
	decode_err := redis.hget_json[JsonUser]('users', 'bad') or {
		assert err.msg().starts_with('redis: json decode failed')
		JsonUser{
			name: 'err'
			age:  -1
		}
	}
	assert decode_err.name == 'err'
}

fn test_json_list_via_encode_decode() ! {
	mut redis := new_client(db: 10)!
	defer {
		redis.close() or {}
	}

	assert redis.flushdb()!

	// Store structs in a list using the generic encode/decode helpers.
	assert redis.rpush('logs', redis.encode(JsonUser{ name: 'alice', age: 30 }))! == 1
	assert redis.rpush('logs', redis.encode(JsonUser{ name: 'bob', age: 25 }))! == 2

	// Fetch and decode.
	raw := redis.lindex('logs', 0)!
	log := redis.decode[JsonUser](raw)!
	assert log.name == 'alice'
	assert log.age == 30

	raw2 := redis.lindex('logs', 1)!
	log2 := redis.decode[JsonUser](raw2)!
	assert log2.name == 'bob'
	assert log2.age == 25
}
