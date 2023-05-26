import unittest
import bloom

suite "leveldb":

  setup:
    var bf = initializeBloomFilter(capacity = 10000, errorRate = 0.001)

  test "params":
    check(bf.capacity == 10000)
    check(bf.errorRate == 0.001)
    check(bf.kHashes == 10)
    check(bf.nBitsPerElem == 15)
    check(bf.mBits == 150000)
    check(bf.useMurmurHash == true)

  test "not hit":
    check(bf.lookup("nothing") == false)

  test "hit":
    bf.insert("hit")
    check(bf.lookup("hit") == true)
