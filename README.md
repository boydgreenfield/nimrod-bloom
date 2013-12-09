nimrod-bloom
============

Bloom filter implementation in Nimrod. Uses a C implementation of MurmurHash3 for optimal speed and numeric distribution.

On a newer Macbook Pro Retina the test case for 1M insertions executes in ~1.3 seconds and 1M lookups in ~1.5 seconds for a Bloom filter with a 1 in 1000 error rate (0.001). This is ~770K insertions/sec and ~660K lookups/sec on a single thread and without any significant optimizations.


Currently supports inserting and looking up string elements. Forthcoming features include:
* Ability to better specify the number of k hash functions desired
* Additional documentation and testing
* Support for other types beyond strings
* Support for iterables in the insert method

Quick functionality demo:
```
var bf = initialize_bloom_filter(capacity = 10000, error_rate = 0.001)
echo(bf.lookup("An element not in the Bloom filter"))  # Prints 'false'
bf.insert("Here we go...")
assert(bf.lookup("Here we go..."))
```

