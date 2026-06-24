module vredis

// hyper_log_log_test verifies the HyperLogLog commands (PFADD / PFCOUNT /
// PFMERGE). HyperLogLog provides approximate cardinality counting with
// fixed memory; the counts are estimates so we assert with tolerance.

fn test_pfadd_pfcount() ! {
	mut redis := new_client(db: 12)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	// Add distinct elements.
	assert redis.pfadd('hll', 'a')! == 1
	assert redis.pfadd('hll', 'b')! == 1
	assert redis.pfadd('hll', 'c')! == 1
	// Re-adding an existing element returns 0 (no change).
	assert redis.pfadd('hll', 'a')! == 0

	// PFCOUNT returns an approximate count of distinct elements.
	count := redis.pfcount('hll')!
	assert count == 3
}

fn test_pfadd_multiple() ! {
	mut redis := new_client(db: 12)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	// Add multiple elements in one call.
	redis.pfadd('hll2', 'x', 'y', 'z', 'w')!

	count := redis.pfcount('hll2')!
	assert count == 4
}

fn test_pfmerge() ! {
	mut redis := new_client(db: 12)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	// Two separate HyperLogLogs.
	redis.pfadd('hll_a', '1', '2', '3')!
	redis.pfadd('hll_b', '3', '4', '5')!

	// Merge into a destination.
	assert redis.pfmerge('hll_merged', 'hll_a', 'hll_b')!

	// Merged count should be the cardinality of the union {1,2,3,4,5}.
	count := redis.pfcount('hll_merged')!
	assert count == 5
}

fn test_pfcount_empty() ! {
	mut redis := new_client(db: 12)!
	defer {
		redis.close() or {}
	}
	assert redis.flushdb()!

	// PFCOUNT on a missing key returns 0.
	assert redis.pfcount('missing_hll')! == 0
}
