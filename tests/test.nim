import unittest
import bloom

suite "leveldb":

  setup:
    var bf = initialize_bloom_filter(capacity = 10000, error_rate = 0.001)

  test "params":
    check(bf.capacity == 10000)
    check(bf.error_rate == 0.001)
    check(bf.k_hashes == 10)
    check(bf.n_bits_per_elem == 15)
    check(bf.m_bits == 150000)
    check(bf.use_murmur_hash == true)

  test "not hit":
    check(bf.lookup("nothing") == false)

  test "hit":
    bf.insert("hit")
    check(bf.lookup("hit") == true)
