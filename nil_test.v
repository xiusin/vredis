module vredis

// nil_test verifies that every command wrapper that can encounter a
// Redis nil reply surfaces it as err_nil (rather than the old "(nil)"
// sentinel string). This guards against regressions if the nil handling
// is ever refactored.

const err_nil_msg = 'redis: nil reply'

fn test_nil_get() ! {
	mut redis := new_client(db: 11)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	// get on a missing key.
	v := redis.get('missing') or {
		assert err.msg() == err_nil_msg
		'nil'
	}
	assert v == 'nil'
}

fn test_nil_getset() ! {
	mut redis := new_client(db: 11)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	// getset on a missing key returns nil for the old value.
	v := redis.getset('missing', 'x') or {
		assert err.msg() == err_nil_msg
		'nil'
	}
	assert v == 'nil'
}

fn test_nil_randomkey() ! {
	mut redis := new_client(db: 11)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	// Empty database → err_nil.
	v := redis.randomkey() or {
		assert err.msg() == err_nil_msg
		'nil'
	}
	assert v == 'nil'
}

fn test_nil_list_ops() ! {
	mut redis := new_client(db: 11)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	// lpop on a missing/empty list.
	mut v := redis.lpop('missing') or {
		assert err.msg() == err_nil_msg
		'nil'
	}
	assert v == 'nil'

	// rpop on a missing/empty list.
	v = redis.rpop('missing') or {
		assert err.msg() == err_nil_msg
		'nil'
	}
	assert v == 'nil'

	// lindex out of range on a missing list.
	v = redis.lindex('missing', 0) or {
		assert err.msg() == err_nil_msg
		'nil'
	}
	assert v == 'nil'

	// lindex out of range on an existing (non-empty) list.
	assert redis.rpush('list', 'a')! == 1
	v = redis.lindex('list', 99) or {
		assert err.msg() == err_nil_msg
		'nil'
	}
	assert v == 'nil'

	// rpoplpush from an empty source.
	v = redis.rpoplpush('missing', 'dest') or {
		assert err.msg() == err_nil_msg
		'nil'
	}
	assert v == 'nil'
}

fn test_nil_spop() ! {
	mut redis := new_client(db: 11)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	// spop on a missing/empty set.
	v := redis.spop('missing') or {
		assert err.msg() == err_nil_msg
		'nil'
	}
	assert v == 'nil'
}

fn test_nil_hget() ! {
	mut redis := new_client(db: 11)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	// hget on a missing key.
	mut v := redis.hget('missing', 'f') or {
		assert err.msg() == err_nil_msg
		'nil'
	}
	assert v == 'nil'

	// hget on an existing key but missing field.
	assert redis.hset('h', 'a', '1')!
	v = redis.hget('h', 'missing_field') or {
		assert err.msg() == err_nil_msg
		'nil'
	}
	assert v == 'nil'
}

fn test_nil_mget() ! {
	mut redis := new_client(db: 11)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	assert redis.set('exists', 'val')!

	// mget with one existing and one missing key.
	m := redis.mget('exists', 'missing')!
	// Existing key is present.
	assert 'exists' in m
	assert m['exists'] == 'val'
	// Missing key is absent from the map (not mapped to "(nil)").
	assert 'missing' !in m
}

fn test_nil_zscore() ! {
	mut redis := new_client(db: 11)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	// zscore on a missing member.
	v := redis.zscore('missing', 'm') or {
		assert err.msg() == err_nil_msg
		-1.0
	}
	assert v == -1.0
}
