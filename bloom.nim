from math import ceil, E, ln, pow, random, randomize, round
import hashes
import strutils
import times
import private/probabilities

# Import MurmurHash3 code and compile at the same time as Nimrod code
{.compile: "murmur3.c".}

type
  EBloomFilter = object of EBase  # Exception for this module
  TMurmurHashes = array[0..1, int]
  TBloomFilter = object
    capacity: int
    error_rate: float
    k_hashes: int
    m_bits: int
    int_array: seq[int]
    n_bits_per_elem: int
    use_murmur_hash: bool

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
  var n_elements_to_test = 100000
  var bf = initialize_bloom_filter(n_elements_to_test, 0.001)
  assert(bf of TBloomFilter)
  echo(bf)

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
