from math import ceil, E, ln, pow, round
import hashes
import strutils


type
  EBloomFilter = object of EBase


type
  TBloomFilter = object of TObject
    capacity: int
    error_rate: float
    k_hashes: int
    m_bits: int
    n_bits_per_elem: int


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
  if k < 1:
    bits_per_elem = ceil(-1.0 * (ln(error_rate) / (pow(ln(2), 2))))
    k_hashes = round(ln(2) * bits_per_elem)
    n_bits_per_elem = round(bits_per_elem)
  else:
    if force_n_bits_per_elem < 1:
      raise newException(EBloomFilter, "Specified a fixed value for k hashes without specifying force_n_bits_per_elem as well.")
    n_bits_per_elem = force_n_bits_per_elem
    k_hashes = k

  m_bits = 1000
  result = TBloomFilter(capacity: capacity, error_rate: error_rate,
                        k_hashes: k_hashes, m_bits: m_bits,
                        n_bits_per_elem: n_bits_per_elem)


proc `$`(bf: TBloomFilter): string =
  result = ("Bloom filter with $1 capacity, $2 error rate, $3 hash functions, and requiring $4 bits per stored element." %
           [$bf.capacity, formatFloat(bf.error_rate, format = ffScientific, precision = 2), $bf.k_hashes, $bf.n_bits_per_elem])


when isMainModule:
  ## Tests
  let bf = initialize_bloom_filter(1000, 0.001)
  assert(bf of TBloomFilter)
  echo(bf)

  let bf2 = initialize_bloom_filter(1000, 0.001, k = 5, force_n_bits_per_elem = 10)
  assert(bf2 of TBloomFilter)
  echo(bf2)