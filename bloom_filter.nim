from math import ceil, E, ln, pow, random, randomize, round
import hashes
import strutils
import times

# TODOS:
# 1) Add table for selecting m over n if the error rate and k are provided
# 2) More testing
# 3) Make code more idiomatic?
# 4) Add more documentation
# 5) Swap built-in hash for MurmurHash3 or similar (and fix hackish string concatenation in hash_b())
# 6) Add hashing for other types besides strings?

const
  bit_setters: array[0..7, int8] = [1'i8, 2'i8, 4'i8, 8'i8, 16'i8, 32'i8, 64'i8, 128'i8]

type
  EBloomFilter = object of EBase

type
  TBloomFilter = object
    capacity: int
    error_rate: float
    k_hashes: int
    m_bits: int
    int_array: seq[int]
    n_bits_per_elem: int

proc hash_a(item: string, max_value: int): int =
  result = hash(item) mod max_value

proc hash_b(item: string, max_value: int): int =
  result = hash(item & " b") mod max_value

proc hash_n(item: string, n: int, max_value: int): int =
  ## Get the nth hash of a string using the formula hash_a + n * hash_b
  ## which uses 2 hash functions vs. k and has comparable properties
  ## See Kirsch and Mitzenmacher, 2008: http://www.eecs.harvard.edu/~kirsch/pubs/bbbf/rsa.pdf
  result = abs((hash_a(item, max_value) + n * hash_b(item, max_value))) mod max_value

proc initialize_bloom_filter*(capacity: int, error_rate: float, k: int = 0, force_n_bits_per_elem: int = 0): TBloomFilter =
  ## Initializes a Bloom filter, using a specified capacity, error rate, and – optionally -
  ## specific number of k hash functions. If k_hashes is < 1 (default argument is 0), k_hashes will be optimally
  ## calculated on the fly. Otherwise, k_hashes will be set to the passed integer, which requires that
  ## force_n_bits_per_elem is also set to be greater than 0.
  ## See http://pages.cs.wisc.edu/~cao/papers/summary-cache/node8.html for useful tables on k and m/n (n bits per element) combinations.
  var k_hashes: int
  var bits_per_elem: float
  var n_bits_per_elem: int
  var m_bits: int
  var m_ints: int
  if k < 1:
    bits_per_elem = ceil(-1.0 * (ln(error_rate) / (pow(ln(2), 2))))
    k_hashes = round(ln(2) * bits_per_elem)
    n_bits_per_elem = round(bits_per_elem)
  else:
    if force_n_bits_per_elem < 1:
      raise newException(EBloomFilter, "Specified a fixed value for k hashes without specifying force_n_bits_per_elem as well.")
    n_bits_per_elem = force_n_bits_per_elem
    k_hashes = k

  m_bits = capacity * n_bits_per_elem
  m_ints = m_bits div sizeof(int)

  result = TBloomFilter(capacity: capacity, error_rate: error_rate,
                        k_hashes: k_hashes, m_bits: m_bits,
                        int_array: newSeq[int](m_ints),
                        n_bits_per_elem: n_bits_per_elem)

proc `$`*(bf: TBloomFilter): string =
  result = ("Bloom filter with $1 capacity, $2 error rate, $3 hash functions, and requiring $4 bits per stored element." %
           [$bf.capacity, formatFloat(bf.error_rate, format = ffScientific, precision = 1), $bf.k_hashes, $bf.n_bits_per_elem])

proc hash(bf: TBloomFilter, item: string): seq[int] =
  var result: seq[int]
  newSeq(result, bf.k_hashes)
  for i in 0..(bf.k_hashes - 1):
    result[i] = hash_n(item, i, bf.m_bits)
  return result

proc insert*(bf: var TBloomFilter, item: string) =
  var hash_set: seq[int]
  var int_address, bit_offset: int
  hash_set = bf.hash(item)
  for h in hash_set:
    int_address = h div sizeof(int)
    bit_offset = h mod sizeof(int)
    bf.int_array[int_address] = bf.int_array[int_address] or (1 shl bit_offset)

proc lookup*(bf: TBloomFilter, item: string): bool =
  var hash_set: seq[int]
  var int_address, bit_offset: int
  var current_byte: int
  hash_set = bf.hash(item)
  for h in hash_set:
    int_address = h div sizeof(int)
    bit_offset = h mod sizeof(int)
    current_byte = bf.int_array[int_address]
    if (current_byte) != (current_byte or (1 shl bit_offset)):
      return false
  return true


when isMainModule:
  ## Some quick and dirty tests (not complete)
  var bf = initialize_bloom_filter(10000, 0.001)
  assert(bf of TBloomFilter)
  echo(bf)

  var bf2 = initialize_bloom_filter(10000, 0.001, k = 5, force_n_bits_per_elem = 10)
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
  var ten_k_elements, sample_letters: seq[string]
  ten_k_elements = newSeq[string](10000)
  sample_letters = newSeq[string](62)

  for i in 0..9999:
    var new_string = ""
    for j in 0..7:
      new_string.add(sample_chars[random(51)])
    ten_k_elements[i] = new_string

  var start_time, end_time: float
  start_time = cpuTime()
  for i in 0..9999:
    bf.insert(ten_k_elements[i])
  end_time = cpuTime()
  echo("Took ", formatFloat(end_time - start_time, format = ffDecimal, precision = 4), " seconds to insert 10k items.")

  var false_positives = 0
  for i in 0..9999:
    var false_positive_string = ""
    for j in 0..8:  # By definition not in bf as 9 chars not 8
      false_positive_string.add(sample_chars[random(51)])
    if bf.lookup(false_positive_string):
      false_positives += 1

  echo("N false positives (of 10k): ", false_positives)
  echo("False positive rate ", formatFloat(false_positives / 10000, format = ffDecimal, precision = 4))

  var lookup_errors = 0
  start_time = cpuTime()
  var t0 = cpuTime()
  for i in 0..9999:
    if not bf.lookup(ten_k_elements[i]):
      lookup_errors += 1
  end_time = cpuTime()
  echo("Took ", formatFloat(end_time - start_time, format = ffDecimal, precision = 4), " seconds to lookup 10k items.")

  echo("N lookup errors (should be 0): ", lookup_errors)
