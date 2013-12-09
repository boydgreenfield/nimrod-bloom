nimrod-bloom
============

Bloom filter implementation in Nimrod. Uses a C implementation of MurmurHash3 for optimal speed and numeric distribution.

On a newer Macbook Pro Retina the test case for 1M insertions executes in ~1.3 seconds and 1M lookups in ~1.5 seconds for a Bloom filter with a 1 in 1000 error rate (0.001). This is ~770K insertions/sec and ~660K lookups/sec on a single thread and without any significant optimizations (this jumps to ~1M ops/sec if k is set to 5 or 6 vs. a larger "optimal" number).


Currently supports inserting and looking up string elements. Forthcoming features include:
* Ability to better specify the number of k hash functions desired
* Additional documentation and testing
* Support for other types beyond strings
* Support for iterables in the insert method


demo
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


By default, the Bloom filter will use a mathematically optimal number of k hash functions, which minimizes the amount of error per bit of storage required. In many cases, however, it may be advantageous to specify a smaller value of k in order to save time hashing. This is supported by passing an explicit `k` parameter, which will then either create an optimal Bloom filter for the specified error rate.*

* If `k` <= 12 and the number of required bytes per element is <= 4. If either of these conditions doesn't hold, a fully manual Bloom filter can be constructed by passing both `k` and `force_n_bits_per_elem`.

Example:
```
var bf2 = initialize_bloom_filter(capacity = 10000, error_rate = 0.001, k = 5)
assert bf2.k == 5
assert bf2.n_bits_per_element == 18

var bf3 = initialize_bloom_filter(capacity = 10000, error_rate = 0.001, k = 5, force_n_bits_per_element = 12)
assert bf3.k == 5
assert bf3.n_bits_per_element == 12   # But note, however, that bf.error rate will *not* be correct
```
