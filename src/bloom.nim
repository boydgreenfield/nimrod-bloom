from math import ceil, ln, pow, round
import hashes
import strutils
import private/probabilities

# Import MurmurHash3 code and compile at the same time as Nim code
{.compile: "murmur3.c".}

type
  BloomFilterError = object of CatchableError
  MurmurHashes = array[0..1, int]
  BloomFilter* = object
    capacity*: int
    errorRate*: float
    kHashes*: int
    mBits*: int
    intArray: seq[int]
    nBitsPerElem*: int
    useMurmurHash*: bool

proc rawMurmurHash(key: cstring, len: int, seed: uint32,
                     outHashes: var MurmurHashes): void {.
  importc: "MurmurHash3_x64_128".}

proc murmurHash(key: string, seed = 0'u32): MurmurHashes =
  rawMurmurHash(key, key.len, seed, outHashes = result)

proc hashA(item: string, maxValue: int): int =
  hash(item) mod maxValue

proc hashB(item: string, maxValue: int): int =
  hash(item & " b") mod maxValue

proc hashN(item: string, n: int, maxValue: int): int =
  ## Get the nth hash of a string using the formula hashA + n * hashB
  ## which uses 2 hash functions vs. k and has comparable properties
  ## See Kirsch and Mitzenmacher, 2008:
  ## http://www.eecs.harvard.edu/~kirsch/pubs/bbbf/rsa.pdf
  abs((hashA(item, maxValue) + n * hashB(item, maxValue))) mod maxValue

proc getMOverNBitsForK(k: int, targetError: float,
    probabilityTable = kErrors): int =
  ## Returns the optimal number of m/n bits for a given k.
  if k notin 0..12:
    raise newException(BloomFilterError,
      "K must be <= 12 if forceNBitsPerElem is not also specified.")

  for mOverN in 2..probabilityTable[k].high:
    if probabilityTable[k][mOverN] < targetError:
      return mOverN

  raise newException(BloomFilterError,
    "Specified value of k and error rate for which is not achievable using less than 4 bytes / element.")

proc initializeBloomFilter*(capacity: int, errorRate: float, k = 0,
                              forceNBitsPerElem = 0,
                              useMurmurHash = true): BloomFilter =
  ## Initializes a Bloom filter, using a specified ``capacity``,
  ## ``errorRate``, and – optionally – specific number of k hash functions.
  ## If ``kHashes`` is < 1 (default argument is 0), ``kHashes`` will be
  ## optimally calculated on the fly. Otherwise, ``kHashes`` will be set to
  ## the passed integer, which requires that ``forceNBitsPerElem`` is
  ## also set to be greater than 0. Otherwise a ``BloomFilterError``
  ## exception is raised.
  ## See http://pages.cs.wisc.edu/~cao/papers/summary-cache/node8.html for
  ## useful tables on k and m/n (n bits per element) combinations.
  ##
  ## The Bloom filter uses the MurmurHash3 implementation by default,
  ## though it can fall back to using the built-in nim ``hash`` function
  ## if ``useMurmurHash = false``. This is compiled alongside the Nim
  ## code using the ``{.compile.}`` pragma.
  var
    kHashes: int
    bitsPerElem: float
    nBitsPerElem: int

  if k < 1: # Calculate optimal k and use that
    bitsPerElem = ceil(-1.0 * (ln(errorRate) / (pow(ln(2.float), 2))))
    kHashes = round(ln(2.float) * bitsPerElem).int
    nBitsPerElem = round(bitsPerElem).int
  else: # Use specified k if possible
    if forceNBitsPerElem < 1: # Use lookup table
      nBitsPerElem = getMOverNBitsForK(k = k, targetError = errorRate)
    else:
      nBitsPerElem = forceNBitsPerElem
    kHashes = k

  let
    mBits = capacity * nBitsPerElem
    mInts = 1 + mBits div (sizeof(int) * 8)

  BloomFilter(capacity: capacity, errorRate: errorRate, kHashes: kHashes,
    mBits: mBits, intArray: newSeq[int](mInts), nBitsPerElem: nBitsPerElem,
    useMurmurHash: useMurmurHash)

proc `$`*(bf: BloomFilter): string =
  ## Prints the capacity, set error rate, number of k hash functions,
  ## and total bits of memory allocated by the Bloom filter.
  "Bloom filter with $1 capacity, $2 error rate, $3 hash functions, and requiring $4 bits per stored element." %
    [$bf.capacity,
     formatFloat(bf.errorRate, format = ffScientific, precision = 1),
     $bf.kHashes, $bf.nBitsPerElem]

{.push overflowChecks: off.}

proc hashMurmur(bf: BloomFilter, key: string): seq[int] =
  result.newSeq(bf.kHashes)
  let murmurHashes = murmurHash(key, seed = 0'u32)
  for i in 0..<bf.kHashes:
    result[i] = abs(murmurHashes[0] + i * murmurHashes[1]) mod bf.mBits

{.pop.}

proc hashNim(bf: BloomFilter, key: string): seq[int] =
  result.newSeq(bf.kHashes)
  for i in 0..<bf.kHashes:
    result[i] = hashN(key, i, bf.mBits)

proc hash(bf: BloomFilter, key: string): seq[int] =
  if bf.useMurmurHash:
    bf.hashMurmur(key)
  else:
    bf.hashNim(key)

proc insert*(bf: var BloomFilter, item: string) =
  ## Insert an item (string) into the Bloom filter.
  var hashSet = bf.hash(item)
  for h in hashSet:
    let
      intAddress = h div (sizeof(int) * 8)
      bitOffset = h mod (sizeof(int) * 8)
    bf.intArray[intAddress] = bf.intArray[intAddress] or (1 shl bitOffset)

proc lookup*(bf: BloomFilter, item: string): bool =
  ## Lookup an item (string) into the Bloom filter.
  ## If the item is present, ``lookup`` is guaranteed to return ``true``.
  ## If the item is not present, ``lookup`` will return ``false``
  ## with a probability 1 - ``bf.errorRate``.
  var hashSet = bf.hash(item)
  for h in hashSet:
    let
      intAddress = h div (sizeof(int) * 8)
      bitOffset = h mod (sizeof(int) * 8)
      currentInt = bf.intArray[intAddress]
    if currentInt != (currentInt or (1 shl bitOffset)):
      return false
  return true

when isMainModule:
  from random import rand, randomize
  import times

  # Test murmurhash 3
  echo("Testing MurmurHash3 code...")
  var hashOutputs: MurmurHashes
  hashOutputs = [0, 0]
  rawMurmurHash("hello", 5, 0, hashOutputs)
  assert int(hashOutputs[0]) == -3758069500696749310 # Correct murmur outputs (cast to int64)
  assert int(hashOutputs[1]) == 6565844092913065241

  let hashOutputs2 = murmurHash("hello", 0)
  assert hashOutputs2[0] == hashOutputs[0]
  assert hashOutputs2[1] == hashOutputs[1]
  let hashOutputs3 = murmurHash("hello", 10)
  assert hashOutputs3[0] != hashOutputs[0]
  assert hashOutputs3[1] != hashOutputs[1]

  # Some quick and dirty tests (not complete)
  var nElementsToTest = 100000
  var bf = initializeBloomFilter(nElementsToTest, 0.001)
  assert(bf of BloomFilter)
  echo(bf)

  var bf2 = initializeBloomFilter(10000, 0.001, k = 4,
      forceNBitsPerElem = 20)
  assert(bf2 of BloomFilter)
  echo(bf2)

  echo("Testing insertions and lookups...")
  echo("Test element in BF2?: ", bf2.lookup("testing"))
  echo("Inserting element.")
  bf2.insert("testing")
  echo("Test element in BF2?: ", bf2.lookup("testing"))
  assert(bf2.lookup("testing"))

  # Now test for speed with bf
  randomize(2882) # Seed the RNG
  var
    sampleChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    kTestElements, sampleLetters: seq[string]
  kTestElements = newSeq[string](nElementsToTest)
  sampleLetters = newSeq[string](62)

  for i in 0..(nElementsToTest - 1):
    var newString = ""
    for j in 0..7:
      newString.add(sampleChars[rand(51)])
    kTestElements[i] = newString

  var startTime, endTime: float
  startTime = cpuTime()
  for i in 0..(nElementsToTest - 1):
    bf.insert(kTestElements[i])
  endTime = cpuTime()
  echo("Took ", formatFloat(endTime - startTime, format = ffDecimal,
      precision = 4), " seconds to insert ", nElementsToTest, " items.")

  var falsePositives = 0
  for i in 0..(nElementsToTest - 1):
    var falsePositiveString = ""
    for j in 0..8: # By definition not in bf as 9 chars not 8
      falsePositiveString.add(sampleChars[rand(51)])
    if bf.lookup(falsePositiveString):
      falsePositives += 1

  echo("N false positives (of ", nElementsToTest, " lookups): ", falsePositives)
  echo("False positive rate ", formatFloat(falsePositives / nElementsToTest,
      format = ffDecimal, precision = 4))

  var lookupErrors = 0
  startTime = cpuTime()
  for i in 0..(nElementsToTest - 1):
    if not bf.lookup(kTestElements[i]):
      lookupErrors += 1
  endTime = cpuTime()
  echo("Took ", formatFloat(endTime - startTime, format = ffDecimal,
      precision = 4), " seconds to lookup ", nElementsToTest, " items.")

  echo("N lookup errors (should be 0): ", lookupErrors)

  # Finally test correct k / mOverN specification,
  # first case raises an error, second works
  try:
    discard getMOverNBitsForK(k = 2, targetError = 0.00001)
    assert false
  except BloomFilterError:
    assert true

  assert getMOverNBitsForK(k = 2, targetError = 0.1) == 6
  assert getMOverNBitsForK(k = 7, targetError = 0.01) == 10
  assert getMOverNBitsForK(k = 7, targetError = 0.001) == 16

  var bf3 = initializeBloomFilter(1000, 0.01, k = 4)
  assert bf3.nBitsPerElem == 11
