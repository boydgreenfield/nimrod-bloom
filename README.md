nimrod-bloom
============

Bloom filter implementation in Nimrod. Uses a C implementation of MurmurHash3 for optimal speed and numeric distribution.

On a newer Macbook Pro Retina the test case for 10M insertions executes in ~4.0 seconds and 10M lookups in ~3.5 seconds for a Bloom filter with a 1 in 1000 error rate (0.001). This is ~2.5M insertions/sec and ~2.9M lookups/sec on a single thread (but passing the `-d:release` flag to the Nimrod compiler and thus activating the C compiler's optimizations). If k is lowered to 5 or 6 vs. a larger "optimal" number, performance further increases to ~4M ops/sec. Note that this test is for a Bloom filter ~20-25MB in size and thus accurately reflects the cost of main memory accesses (vs. a smaller filter that might fit solely in L3 cache, for example, and can achieve several million additional ops/sec).


Currently supports inserting and looking up string elements. Forthcoming features include:
* Support for other types beyond strings
* Support for iterables in the insert method
* Persistence


quickstart
====
Quick functionality demo:
```
import bloom
var bf = initialize_bloom_filter(capacity = 10000, error_rate = 0.001)
echo(bf)  											   # Get characteristics of the Bloom filter
echo(bf.lookup("An element not in the Bloom filter"))  # Prints 'false'
bf.insert("Here we go...")
assert(bf.lookup("Here we go..."))
```


By default, the Bloom filter will use a mathematically optimal number of k hash functions, which minimizes the amount of error per bit of storage required. In many cases, however, it may be advantageous to specify a smaller value of k in order to save time hashing. This is supported by passing an explicit `k` parameter, which will then either create an optimal Bloom filter for the specified error rate.[1]

[1] If `k` <= 12 and the number of required bytes per element is <= 4. If either of these conditions doesn't hold, a fully manual Bloom filter can be constructed by passing both `k` and `force_n_bits_per_elem`.

Example:
```
var bf2 = initialize_bloom_filter(capacity = 10000, error_rate = 0.001, k = 5)
assert bf2.k_hashes == 5
assert bf2.n_bits_per_elem == 18

var bf3 = initialize_bloom_filter(capacity = 10000, error_rate = 0.001, k = 5, force_n_bits_per_elem = 12)
assert bf3.k_hashes == 5
assert bf3.n_bits_per_elem == 12   # But note, however, that bf.error_rate will *not* be correct
```
