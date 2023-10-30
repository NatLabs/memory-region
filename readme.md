## MemoryRegion
MemoryRegion provides an abstraction over Motoko's native [Region](https://internetcomputer.org/docs/current/motoko/main/base/Region/) type, enabling users to reuse deallocated memory blocks efficiently.

## Why Use MemoryRegion?
While Motoko's `Region` type effectively isolates sections of stable memory, it lacks a built-in mechanism for freeing up unused memory blocks. This can result in memory fragmentation, pushing users to develop their own memory management systems. MemoryRegion solves this problem by providing an interface, which extends the `Region` type with a few additional functions for managing memory:
  - `allocate` - allocates a memory block of a given size and returns its address
  - `deallocate` - deallocates a memory block of a given size
  - `addBlob` - allocates enough memory for the given blob, inserts the blob into the `Region` and returns the memory block's address.
  - `removeBlob` - Extracts the blob at the given address from the `Region` and frees up the associated memory block.

## How it works
Internally, the `MemoryRegion` stores data in a `Region`, updating a size counter that keeps track of the total allocated memory, and two [btree](https://github.com/canscale/StableHeapBTreeMap) maps for managing the free memory blocks.
The first map orderes the blocks by their addresses, while the second map orders them by their sizes. This strategy enables each `MemoryRegion` to allocate and deallocate memory blocks in `O(log n)` time.

## Pros and Cons
### Pros
- Merges adjecent memory blocks, reducing the number of free memory blocks stored on the heap
- Fast Allocation and deallocation
- Minimized risk of memory fragmentation.

### Cons
- Memory blocks are duplicated between the two ordered maps in order to ensure log(n) time for allocation and deallocation

### Getting Started
#### Installation
- Install mops
- Run `mops add memory-region`

#### Import Module
```motoko
  import { MemoryRegion } "mo:memory-region";
```
#### Usage
- Store and remove data from a `MemoryRegion`
```motoko

  let memory_region = MemoryRegion.new();

  let blob = Blob.fromArray([1, 2, 3, 4]);
  let blob_size = blob.size();

  let address = MemoryRegion.addBlob(memory_region, blob);
  assert blob == MemoryRegion.loadBlob(memory_region, address, blob_size);

  let #ok(removed_blob) = MemoryRegion.removeBlob(memory_region, address, blob_size);
  assert MemoryRegion.getFreeMemory(memory_region) == [(address, blob_size)];
  assert removed_blob == blob;

  assert MemoryRegion.addBlob(memory_region, blob) == address;
  assert MemoryRegion.getFreeMemory(memory_region) == [];
```

- Using `MemoryRegion` to manage memory internally within a custom data-structure
```motoko
  import Region "mo:base/Region";

  let memory_region = MemoryRegion.new();

  let blob = Blob.fromArray([1, 2, 3, 4]);
  let blob_size = blob.size();

  let address = MemoryRegion.allocate(memory_region, blob_size);

  MemoryRegion.storeBlob(memory_region.region, address, blob_size);

  assert #ok() == MemoryRegion.deallocate(memory_region, blob_ptr);
  
```

## Benchmarks
Region vs MemoryRegion

Benchmarking the performance with 10k entries


#### Instructions

|              |  addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | ---------: | -----------: | ---------------------------: |
| Region       |  7_219_214 |            - |                            - |
| MemoryRegion | 11_380_427 |  171_654_817 |                  152_081_540 |


#### Heap

|              | addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | --------: | -----------: | ---------------------------: |
| Region       |     9_040 |            - |                            - |
| MemoryRegion |     9_040 |    3_213_880 |                    3_168_140 |
