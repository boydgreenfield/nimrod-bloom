from math import ceil, E, ln, pow, random, randomize, round
import hashes
import strutils
import times

# Import MurmurHash3 code and compile at the same time as Nimrod code
{.compile: "murmur3.c".}

#
# ### Initial probability table declaration ###
# Table for k hashes from 1..12 from http://pages.cs.wisc.edu/~cao/papers/summary-cache/node8.html
# Iterate along the sequence at position [k] until the error rate is < specified, otherwise
# raise an error.
#
type
  EBloomFilter = object of EBase  # Exception for this module
  TErrorForK = seq[float]
  TAllErrorRates = array[0..12, TErrorForK]

var k_errors: TAllErrorRates

k_errors[0] = @[1.0]
k_errors[1] = @[1.0, 1.0,
              0.3930000000, 0.2830000000, 0.2210000000, 0.1810000000, 0.1540000000,
              0.1330000000, 0.1180000000, 0.1050000000, 0.0952000000, 0.0869000000,
              0.0800000000, 0.0740000000, 0.0689000000, 0.0645000000, 0.0606000000,
              0.0571000000, 0.0540000000, 0.0513000000, 0.0488000000, 0.0465000000,
              0.0444000000, 0.0425000000, 0.0408000000, 0.0392000000, 0.0377000000,
              0.0364000000, 0.0351000000, 0.0339000000, 0.0328000000, 0.0317000000,
              0.0308000000 ]

k_errors[2] = @[1.0, 1.0,
              0.4000000000, 0.2370000000, 0.1550000000, 0.1090000000, 0.0804000000,
              0.0618000000, 0.0489000000, 0.0397000000, 0.0329000000, 0.0276000000,
              0.0236000000, 0.0203000000, 0.0177000000, 0.0156000000, 0.0138000000,
              0.0123000000, 0.0111000000, 0.0099800000, 0.0090600000, 0.0082500000,
              0.0075500000, 0.0069400000, 0.0063900000, 0.0059100000, 0.0054800000,
              0.0051000000, 0.0047500000, 0.0044400000, 0.0041600000, 0.0039000000,
              0.0036700000 ]

k_errors[3] = @[1.0, 1.0, 1.0,
              0.2530000000, 0.1470000000, 0.0920000000, 0.0609000000, 0.0423000000,
              0.0306000000, 0.0228000000, 0.0174000000, 0.0136000000, 0.0108000000,
              0.0087500000, 0.0071800000, 0.0059600000, 0.0050000000, 0.0042300000,
              0.0036200000, 0.0031200000, 0.0027000000, 0.0023600000, 0.0020700000,
              0.0018300000, 0.0016200000, 0.0014500000, 0.0012900000, 0.0011600000,
              0.0010500000, 0.0009490000, 0.0008620000, 0.0007850000, 0.0007170000 ]

k_errors[4] = @[1.0, 1.0, 1.0, 1.0,
              0.1600000000, 0.0920000000, 0.0561000000, 0.0359000000, 0.0240000000,
              0.0166000000, 0.0118000000, 0.0086400000, 0.0064600000, 0.0049200000,
              0.0038100000, 0.0030000000, 0.0023900000, 0.0019300000, 0.0015800000,
              0.0013000000, 0.0010800000, 0.0009050000, 0.0007640000, 0.0006490000,
              0.0005550000, 0.0004780000, 0.0004130000, 0.0003590000, 0.0003140000,
              0.0002760000, 0.0002430000, 0.0002150000, 0.0001910000 ]

k_errors[5] = @[1.0, 1.0, 1.0, 1.0, 1.0,
              0.1010000000, 0.0578000000, 0.0347000000, 0.0217000000, 0.0141000000,
              0.0094300000, 0.0065000000, 0.0045900000, 0.0033200000, 0.0024400000,
              0.0018300000, 0.0013900000, 0.0010700000, 0.0008390000, 0.0006630000,
              0.0005300000, 0.0004270000, 0.0003470000, 0.0002850000, 0.0002350000,
              0.0001960000, 0.0001640000, 0.0001380000, 0.0001170000, 0.0000996000,
              0.0000853000, 0.0000733000, 0.0000633000 ]

k_errors[6] = @[1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
              0.0638000000, 0.0364000000, 0.0216000000, 0.0133000000, 0.0084400000,
              0.0055200000, 0.0037100000, 0.0025500000, 0.0017900000, 0.0012800000,
              0.0009350000, 0.0006920000, 0.0005190000, 0.0003940000, 0.0003030000,
              0.0002360000, 0.0001850000, 0.0001470000, 0.0001170000, 0.0000944000,
              0.0000766000, 0.0000626000, 0.0000515000, 0.0000426000, 0.0000355000,
              0.0000297000, 0.0000250000 ]

k_errors[7] = @[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
              0.0229000000, 0.0135000000, 0.0081900000, 0.0051300000, 0.0032900000,
              0.0021700000, 0.0014600000, 0.0010000000, 0.0007020000, 0.0004990000,
              0.0003600000, 0.0002640000, 0.0001960000, 0.0001470000, 0.0001120000,
              0.0000856000, 0.0000663000, 0.0000518000, 0.0000408000, 0.0000324000,
              0.0000259000, 0.0000209000, 0.0000169000, 0.0000138000, 0.0000113000 ]

k_errors[8] = @[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
              0.0145000000, 0.0084600000, 0.0050900000, 0.0031400000, 0.0019900000,
              0.0012900000, 0.0008520000, 0.0005740000, 0.0003940000, 0.0002750000,
              0.0001940000, 0.0001400000, 0.0001010000, 0.0000746000, 0.0000555000,
              0.0000417000, 0.0000316000, 0.0000242000, 0.0000187000, 0.0000146000,
              0.0000114000, 0.0000090100, 0.0000071600, 0.0000057300 ]

k_errors[9] = @[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
              0.0053100000, 0.0031700000, 0.0019400000, 0.0012100000, 0.0007750000,
              0.0005050000, 0.0003350000, 0.0002260000, 0.0001550000, 0.0001080000,
              0.0000759000, 0.0000542000, 0.0000392000, 0.0000286000, 0.0000211000,
              0.0000157000, 0.0000118000, 0.0000089600, 0.0000068500, 0.0000052800,
              0.0000041000, 0.0000032000]

k_errors[10] = @[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
              0.0033400000, 0.0019800000, 0.0012000000, 0.0007440000, 0.0004700000,
              0.0003020000, 0.0001980000, 0.0001320000, 0.0000889000, 0.0000609000,
              0.0000423000, 0.0000297000, 0.0000211000, 0.0000152000, 0.0000110000,
              0.0000080700, 0.0000059700, 0.0000044500, 0.0000033500, 0.0000025400,
              0.0000019400]

k_errors[11] = @[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
              0.0021000000, 0.0012400000, 0.0007470000, 0.0004590000, 0.0002870000,
              0.0001830000, 0.0001180000, 0.0000777000, 0.0000518000, 0.0000350000,
              0.0000240000, 0.0000166000, 0.0000116000, 0.0000082300, 0.0000058900,
              0.0000042500, 0.0000031000, 0.0000022800, 0.0000016900, 0.0000012600]

k_errors[12] = @[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
              0.0007780000, 0.0004660000, 0.0002840000, 0.0001760000, 0.0001110000,
              0.0000712000, 0.0000463000, 0.0000305000, 0.0000204000, 0.0000138000,
              0.0000094200, 0.0000065200, 0.0000045600, 0.0000032200, 0.0000022900,
              0.0000016500, 0.0000012000, 0.0000008740]

proc get_m_over_n_bits_for_k(k: int, target_error: float, probability_table: TAllErrorRates = k_errors): int =
  ## Returns the optimal number of m/n bits for a given k.
  if k > 12:
    raise newException(EBloomFilter, "K must be <= 12 if force_n_bits_per_elem is not also specified.")
  var searching_for_m_over_n = true
  var m_over_n = 2
  while searching_for_m_over_n:
    try:
      if probability_table[k][m_over_n] < target_error:
        searching_for_m_over_n = false
        result = m_over_n
        return result
      else:
        m_over_n += 1
    except EInvalidIndex:
      raise newException(EBloomFilter, "Specified value of k and error rate for which is not achievable using less than 4 bytes / element.")

#
# ### End of probability table ###
#

type
  TBloomFilter = object
    capacity: int
    error_rate: float
    k_hashes: int
    m_bits: int
    int_array: seq[int]
    n_bits_per_elem: int
    use_murmur_hash: bool

type
  TMurmurHashes = array[0..1, int]

proc raw_murmur_hash(key: cstring, len: int, seed: uint32, out_hashes: var TMurmurHashes): void {.
  importc: "MurmurHash3_x64_128".}

proc murmur_hash(key: string, seed: uint32 = 0'u32): TMurmurHashes =
  var result: TMurmurHashes = [0, 0]
  raw_murmur_hash(key = key, len = key.len, seed = seed, out_hashes = result)
  return result

proc hash_a(item: string, max_value: int): int =
  result = hash(item) mod max_value

proc hash_b(item: string, max_value: int): int =
  result = hash(item & " b") mod max_value

proc hash_n(item: string, n: int, max_value: int): int =
  ## Get the nth hash of a string using the formula hash_a + n * hash_b
  ## which uses 2 hash functions vs. k and has comparable properties
  ## See Kirsch and Mitzenmacher, 2008: http://www.eecs.harvard.edu/~kirsch/pubs/bbbf/rsa.pdf
  result = abs((hash_a(item, max_value) + n * hash_b(item, max_value))) mod max_value

proc initialize_bloom_filter*(capacity: int, error_rate: float, k: int = 0, force_n_bits_per_elem: int = 0, use_murmur_hash: bool = true): TBloomFilter =
  ## Initializes a Bloom filter, using a specified ``capacity``, ``error_rate``, and – optionally –
  ## specific number of k hash functions. If ``k_hashes`` is < 1 (default argument is 0), ``k_hashes`` will be optimally
  ## calculated on the fly. Otherwise, ``k_hashes`` will be set to the passed integer, which requires that
  ## ``force_n_bits_per_elem`` is also set to be greater than 0. Otherwise a ``EBloomFilter`` exception is raised.
  ## See http://pages.cs.wisc.edu/~cao/papers/summary-cache/node8.html for useful tables on k and m/n (n bits per element) combinations.
  ##
  ## The Bloom filter uses the MurmurHash3 implementation by default, though it can fall back to using the built-in nimrod ``hash`` function
  ## if ``use_murmur_hash = false``. This is compiled alongside the Nimrod code using the ``{.compile.}`` pragma.
  var k_hashes: int
  var bits_per_elem: float
  var n_bits_per_elem: int
  if k < 1:  # Calculate optimal k and use that
    bits_per_elem = ceil(-1.0 * (ln(error_rate) / (pow(ln(2), 2))))
    k_hashes = round(ln(2) * bits_per_elem)
    n_bits_per_elem = round(bits_per_elem)
  else:      # Use specified k if possible
    if force_n_bits_per_elem < 1:  # Use lookup table
      n_bits_per_elem = get_m_over_n_bits_for_k(k = k, target_error = error_rate)
    else:
      n_bits_per_elem = force_n_bits_per_elem
    k_hashes = k

  let m_bits = capacity * n_bits_per_elem
  let m_ints = 1 + m_bits div (sizeof(int) * 8)

  result = TBloomFilter(capacity: capacity, error_rate: error_rate,
                        k_hashes: k_hashes, m_bits: m_bits,
                        int_array: newSeq[int](m_ints),
                        n_bits_per_elem: n_bits_per_elem,
                        use_murmur_hash: use_murmur_hash)

proc `$`*(bf: TBloomFilter): string =
  ##  Prints the capacity, set error rate, number of k hash functions, and total bits of memory allocated by the Bloom filter.
  result = ("Bloom filter with $1 capacity, $2 error rate, $3 hash functions, and requiring $4 bits per stored element." %
           [$bf.capacity, formatFloat(bf.error_rate, format = ffScientific, precision = 1), $bf.k_hashes, $bf.n_bits_per_elem])

{.push overflowChecks: off.}

proc hash_murmur(bf: TBloomFilter, item: string): seq[int] =
  result = newSeq[int](bf.k_hashes)
  let murmur_hashes = murmur_hash(key = item, seed = 0'u32)
  for i in 0..(bf.k_hashes - 1):
    result[i] = abs(murmur_hashes[0] + i * murmur_hashes[1]) mod bf.m_bits
  return result

{.pop.}

proc hash_nimrod(bf: TBloomFilter, item: string): seq[int] =
  var result: seq[int]
  newSeq(result, bf.k_hashes)
  for i in 0..(bf.k_hashes - 1):
    result[i] = hash_n(item, i, bf.m_bits)
  return result

proc hash(bf: TBloomFilter, item: string): seq[int] =
  if bf.use_murmur_hash:
    result = bf.hash_murmur(item = item)
  else:
    result = bf.hash_nimrod(item = item)
  return result

proc insert*(bf: var TBloomFilter, item: string) =
  ## Insert an item (string) into the Bloom filter. Can be called with method style syntax like ``bf.insert("test item")``.
  var hash_set = bf.hash(item)
  for h in hash_set:
    let int_address = h div (sizeof(int) * 8)
    let bit_offset = h mod (sizeof(int) * 8)
    bf.int_array[int_address] = bf.int_array[int_address] or (1 shl bit_offset)

proc lookup*(bf: TBloomFilter, item: string): bool =
  ## Lookup an item (string) into the Bloom filter. Can be called with method style syntax like ``bf.lookup("test item")``.
  ## If the item is present, ``lookup`` is guaranteed to return ``true``. If the item is not present, ``lookup`` will return ``false``
  ## with a probability 1 - ``bf.error_rate``.
  var hash_set = bf.hash(item)
  for h in hash_set:
    let int_address = h div (sizeof(int) * 8)
    let bit_offset = h mod (sizeof(int) * 8)
    let current_int = bf.int_array[int_address]
    if (current_int) != (current_int or (1 shl bit_offset)):
      return false
  return true


when isMainModule:
  # Test murmurhash 3
  echo("Testing MurmurHash3 code...")
  var hash_outputs: TMurmurHashes
  hash_outputs = [0, 0]
  raw_murmur_hash("hello", 5, 0, hash_outputs)
  assert int(hash_outputs[0]) == -3758069500696749310  # Correct murmur outputs (cast to int64)
  assert int(hash_outputs[1]) == 6565844092913065241

  let hash_outputs2 = murmur_hash("hello", 0)
  assert hash_outputs2[0] == hash_outputs[0]
  assert hash_outputs2[1] == hash_outputs[1]
  let hash_outputs3 = murmur_hash("hello", 10)
  assert hash_outputs3[0] != hash_outputs[0]
  assert hash_outputs3[1] != hash_outputs[1]

  # Some quick and dirty tests (not complete)
  var n_elements_to_test = 1000000
  var bf = initialize_bloom_filter(n_elements_to_test, 0.001)
  assert(bf of TBloomFilter)

  var bf2 = initialize_bloom_filter(10000, 0.001, k = 4, force_n_bits_per_elem = 20)
  assert(bf2 of TBloomFilter)
  echo(bf2)

  echo("Testing insertions and lookups...")
  echo("Test element in BF2?: ", bf2.lookup("testing"))
  echo("Inserting element.")
  bf2.insert("testing")
  echo("Test element in BF2?: ", bf2.lookup("testing"))
  assert(bf2.lookup("testing"))

  # Now test for speed with bf
  randomize(2882)  # Seed the RNG
  var sample_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  var k_test_elements, sample_letters: seq[string]
  k_test_elements = newSeq[string](n_elements_to_test)
  sample_letters = newSeq[string](62)

  for i in 0..(n_elements_to_test - 1):
    var new_string = ""
    for j in 0..7:
      new_string.add(sample_chars[random(51)])
    k_test_elements[i] = new_string

  var start_time, end_time: float
  start_time = cpuTime()
  for i in 0..(n_elements_to_test - 1):
    bf.insert(k_test_elements[i])
  end_time = cpuTime()
  echo("Took ", formatFloat(end_time - start_time, format = ffDecimal, precision = 4), " seconds to insert ", n_elements_to_test, " items.")

  var false_positives = 0
  for i in 0..(n_elements_to_test - 1):
    var false_positive_string = ""
    for j in 0..8:  # By definition not in bf as 9 chars not 8
      false_positive_string.add(sample_chars[random(51)])
    if bf.lookup(false_positive_string):
      false_positives += 1

  echo("N false positives (of ", n_elements_to_test, " lookups): ", false_positives)
  echo("False positive rate ", formatFloat(false_positives / n_elements_to_test, format = ffDecimal, precision = 4))

  var lookup_errors = 0
  start_time = cpuTime()
  for i in 0..(n_elements_to_test - 1):
    if not bf.lookup(k_test_elements[i]):
      lookup_errors += 1
  end_time = cpuTime()
  echo("Took ", formatFloat(end_time - start_time, format = ffDecimal, precision = 4), " seconds to lookup ", n_elements_to_test, " items.")

  echo("N lookup errors (should be 0): ", lookup_errors)

  # Finally test correct k / m_over_n specification, first case raises an error, second works
  try:
    let m1 = get_m_over_n_bits_for_k(k = 2, target_error = 0.00001)
    assert false
  except EBloomFilter:
    assert true

  assert get_m_over_n_bits_for_k(k = 2, target_error = 0.1) == 6
  assert get_m_over_n_bits_for_k(k = 7, target_error = 0.01) == 10
  assert get_m_over_n_bits_for_k(k = 7, target_error = 0.001) == 16

  var bf3 = initialize_bloom_filter(1000, 0.01, k = 4)  # Should require 11 bits per element
  assert bf3.n_bits_per_elem == 11
