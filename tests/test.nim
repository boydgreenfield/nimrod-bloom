import unittest
include bloom
from random import rand, randomize
import times

suite "murmur":
  # Test murmurhash 3
  setup:
    var hashOutputs: MurmurHashes
    hashOutputs = [0, 0]
    rawMurmurHash("hello", 5, 0, hashOutputs)

  test "raw":
    check int(hashOutputs[0]) == -3758069500696749310 # Correct murmur outputs (cast to int64)
    check int(hashOutputs[1]) == 6565844092913065241

  test "wrapped":
    let hashOutputs2 = murmurHash("hello", 0)
    check hashOutputs2[0] == hashOutputs[0]
    check hashOutputs2[1] == hashOutputs[1]

  test "seed":
    let hashOutputs3 = murmurHash("hello", 10)
    check hashOutputs3[0] != hashOutputs[0]
    check hashOutputs3[1] != hashOutputs[1]


suite "bloom":

  setup:
    let nElementsToTest = 100000
    var bf = initializeBloomFilter(capacity = nElementsToTest, errorRate = 0.001)
    randomize(2882) # Seed the RNG
    var
      sampleChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
      kTestElements, sampleLetters: seq[string]
    kTestElements = newSeq[string](nElementsToTest)
    sampleLetters = newSeq[string](62)

    for i in 0..<nElementsToTest:
      var newString = ""
      for j in 0..7:
        newString.add(sampleChars[rand(51)])
      kTestElements[i] = newString

    for i in 0..<nElementsToTest:
      bf.insert(kTestElements[i])

  test "params":
    check(bf.capacity == nElementsToTest)
    check(bf.errorRate == 0.001)
    check(bf.kHashes == 10)
    check(bf.nBitsPerElem == 15)
    check(bf.mBits == 15 * nElementsToTest)
    check(bf.useMurmurHash == true)

  test "not hit":
    check(bf.lookup("nothing") == false)

  test "hit":
    bf.insert("hit")
    check(bf.lookup("hit") == true)

  test "force params":
    var bf2 = initializeBloomFilter(10000, 0.001, k = 4, forceNBitsPerElem = 20)
    check(bf2.capacity == 10000)
    check(bf2.errorRate == 0.001)
    check(bf2.kHashes == 4)
    check(bf2.nBitsPerElem == 20)
    check(bf2.mBits == 200000)
    check(bf2.useMurmurHash == true)

  test "error rate":
    var falsePositives = 0
    for i in 0..<nElementsToTest:
      var falsePositiveString = ""
      for j in 0..8: # By definition not in bf as 9 chars not 8
        falsePositiveString.add(sampleChars[rand(51)])
      if bf.lookup(falsePositiveString):
        falsePositives += 1

    check falsePositives / nElementsToTest < bf.errorRate

  test "lookup errors":
    var lookupErrors = 0
    for i in 0..<nElementsToTest:
      if not bf.lookup(kTestElements[i]):
        lookupErrors += 1

    check lookupErrors == 0

  # Finally test correct k / mOverN specification,
  test "k/(m/n) spec":
    expect(BloomFilterError):
      discard getMOverNBitsForK(k = 2, targetError = 0.00001)

    check getMOverNBitsForK(k = 2, targetError = 0.1) == 6
    check getMOverNBitsForK(k = 7, targetError = 0.01) == 10
    check getMOverNBitsForK(k = 7, targetError = 0.001) == 16

    var bf3 = initializeBloomFilter(1000, 0.01, k = 4)
    check bf3.nBitsPerElem == 11
