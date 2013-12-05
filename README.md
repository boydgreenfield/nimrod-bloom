nimrod-bloom
============

Bloom filter implementation in Nimrod.


Currently supports inserting and looking up string elements. Forthcoming features include:
* Ability to better specify the number of k hash functions desired
* Faster hashing behind-the-scenes
* Additional documentation and testing
* Support for other types beyond strings

Quick functionality demo:
```
var bf = initialize_bloom_filter(capacity = 10000, error_rate = 0.001)
echo(bf.lookup("An element not in the Bloom filter"))  # Prints 'false'
bf.insert("Here we go...")
assert(bf.lookup("Here we go..."))
```

