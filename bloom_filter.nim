from math import ceil, E, ln, pow, round
import hashes
import strutils


const
  bit0: int8 = 1'i8
  bit1: int8 = 2'i8
  bit2: int8 = 4'i8
  bit3: int8 = 8'i8
  bit4: int8 = 16'i8
  bit5: int8 = 32'i8
  bit6: int8 = 64'i8
  bit7: int8 = 128'i8
  bit_setters: array[0..7, int8] = [1'i8, 2'i8, 4'i8, 8'i8, 16'i8, 32'i8, 64'i8, 128'i8]


type
  EBloomFilter = object of EBase


type
  TBloomFilter = object
    capacity: int
    error_rate: float
    k_hashes: int
    m_bits: int
    bit_array: seq[int8]
    n_bits_per_elem: int



proc hash_a(item: string, max_value: int): int =
  result = hash(item) mod max_value

proc hash_b(item: string, max_value: int): int =
  result = hash(item & " b") mod max_value

proc hash_n(item: string, n: int, max_value: int): int =
  result = abs((hash_a(item, max_value) + n * hash_b(item, max_value))) mod max_value

proc initialize_bloom_filter(capacity: int, error_rate: float, k: int = 0, force_n_bits_per_elem: int = 0): TBloomFilter =
  ## Initializes a Bloom filter, using a specified capacity, error rate, and – optionally -
  ## specific number of k hash functions. If k_hashes is < 1 (default argument is 0), k_hashes will be optimally
  #$ calculated on the fly. Otherwise, k_hashes will be set to the passed integer, which requires that
  ## force_n_bits_per_elem is also set to be greater than 0.
  ## See http://pages.cs.wisc.edu/~cao/papers/summary-cache/node8.html for useful tables on k and m/n (n bits per element) combinations.
  var k_hashes: int
  var bits_per_elem: float
  var n_bits_per_elem: int
  var m_bits: int
  var m_bytes: int
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
  m_bytes = m_bits div 8

  result = TBloomFilter(capacity: capacity, error_rate: error_rate,
                        k_hashes: k_hashes, m_bits: m_bits,
                        bit_array: newSeq[int8](m_bytes),
                        n_bits_per_elem: n_bits_per_elem)


proc `$`(bf: TBloomFilter): string =
  result = ("Bloom filter with $1 capacity, $2 error rate, $3 hash functions, and requiring $4 bits per stored element." %
           [$bf.capacity, formatFloat(bf.error_rate, format = ffScientific, precision = 2), $bf.k_hashes, $bf.n_bits_per_elem])


proc hash(bf: TBloomFilter, item: string): seq[int] =
  var result: seq[int]
  newSeq(result, bf.k_hashes)
  for i in 0..(bf.k_hashes - 1):
    result[i] = hash_n(item, i, bf.m_bits)
  return result


proc insert(bf: var TBloomFilter, item: string) =
  var hash_set: seq[int]
  var byte_address, bit_offset: int
  hash_set = bf.hash(item)
  for h in hash_set:
    byte_address = h div 8
    bit_offset = h mod 8
    #echo("Byte is     ", toBin(bf.bit_array[byte_address], 8))
    bf.bit_array[byte_address] = bf.bit_array[byte_address] or bit_setters[bit_offset]
    #echo("Offset is   ", toBin(bit_setters[bit_offset], 8))
    #echo("Byte now is ", toBin(bf.bit_array[byte_address], 8))


proc lookup(bf: TBloomFilter, item: string): bool =
  var hash_set: seq[int]
  var byte_address, bit_offset: int
  var current_byte: int8
  hash_set = bf.hash(item)
  for h in hash_set:
    byte_address = h div 8
    bit_offset = h mod 8
    current_byte = bf.bit_array[byte_address]
    if (current_byte) != (current_byte or bit_setters[bit_offset]):
      return false
  return true



when isMainModule:
  ## Tests
  var bf = initialize_bloom_filter(100000, 0.001)
  assert(bf of TBloomFilter)
  echo(bf)

  var bf2 = initialize_bloom_filter(100000, 0.001, k = 5, force_n_bits_per_elem = 10)
  assert(bf2 of TBloomFilter)
  echo(bf2)

  echo("Testing insertions and lookups...")
  echo("Test element in BF2?: ", bf2.lookup("testing"))
  echo("Inserting element.")
  bf2.insert("testing")
  echo("Test element in BF2?: ", bf2.lookup("testing"))
