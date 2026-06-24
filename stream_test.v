module vredis

fn test_stream() ! {
	mut redis := new_client(db: 7)!
	defer {
		redis.close() or {}
	}

	key := 'rediv_stream'

	redis.flushdb()!

	id := redis.xadd(key, '*', 'name', 'vlang')!

	assert redis.xdel(key, id)! == 1

	assert redis.xlen(key)! == 0
}

fn test_stream_xrange() ! {
	mut redis := new_client(db: 7)!
	defer {
		redis.close() or {}
	}

	key := 'stream_xrange'
	redis.flushdb()!

	// Add three entries with server-generated IDs.
	id1 := redis.xadd(key, '*', 'field', 'value1', 'extra', 'e1')!
	id2 := redis.xadd(key, '*', 'field', 'value2')!
	id3 := redis.xadd(key, '*', 'field', 'value3')!

	assert redis.xlen(key)! == 3

	// xrange over the full range returns all entries.
	// Each entry flattens to [id, field, value, ...].
	all := redis.xrange(key, '-', '+')!
	assert all.len >= 6 // at least id + field/value pairs across entries
	assert all[0] == id1

	// xrange with a start after id1 should skip it.
	// Use id2 as the start (inclusive).
	partial := redis.xrange(key, id2, '+')!
	assert partial.len >= 4
	assert partial[0] == id2
}

fn test_stream_xtrim() ! {
	mut redis := new_client(db: 7)!
	defer {
		redis.close() or {}
	}

	key := 'stream_xtrim'
	redis.flushdb()!

	// Add 5 entries.
	for i := 0; i < 5; i++ {
		redis.xadd(key, '*', 'f', 'v${i}')!
	}
	assert redis.xlen(key)! == 5

	// Trim to approximately 2 entries (approx flag).
	// Approx trimming may retain more entries, so only assert the call
	// succeeds and the length stays within bounds.
	trimmed := redis.xtrim(key, 2, true)!
	assert trimmed >= 0
	assert redis.xlen(key)! <= 5

	// Exact trim to 1.
	redis.xtrim(key, 1)!
	assert redis.xlen(key)! <= 1
}
