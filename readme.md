## MemoryRegion
MemoryRegion provides an abstraction over Motoko's native [Region](https://internetcomputer.org/docs/current/motoko/main/base/Region/) type, enabling users to reuse deallocated memory blocks efficiently.

## Why Use MemoryRegion?
While Motoko's `Region` type effectively isolates sections of stable memory, it lacks a built-in mechanism for freeing up unused memory blocks. This can result in memory fragmentation, pushing users to develop their own memory management systems. MemoryRegion solves this problem by providing an interface, which extends the `Region` type with a few additional functions for managing memory:
  - `allocate` - allocates a memory block of a given size and returns its address
  - `deallocate` - deallocates a memory block of a given size
  - `addBlob` - allocates enough memory for the given blob, inserts the blob into the `Region` and returns the memory block's address.
  - `removeBlob` - Extracts the blob at the given address from the `Region` and frees up the associated memory block.


## How it works
Internally, the `MemoryRegion` stores data in a `Region`, updating a size counter that keeps track of the total allocated memory, and a specialized Max B+Tree for managing the free memory blocks.
The tree orders the memory blocks by their addresses, and stores the keeps a reference to the block with the largest size in each of its nodes. This strategy enables the `MemoryRegion` to allocate and deallocate memory blocks in `O(log n)` time.

## Pros and Cons
### Pros
- Merges adjecent memory blocks, reducing the number of free memory blocks stored on the heap
- Fast Allocation and deallocation
- Minimized risk of memory fragmentation.

### Cons
- Deallocated memory is stored on the heap, which has a limited size and can cause memory leaks if not managed properly during upgrades.

### Getting Started
#### Installation
- Install mops
- Run `mops add memory-region`

#### Import Module

This library provides two implementations of the MemoryRegion:
- Regular Module 
```motoko
  import MemoryRegion "mo:memory-region/MemoryRegion";
```
- and a Versioned Module
```motoko
  import MemoryRegion "mo:memory-region/VersionedMemoryRegion";
```

The versioned implementation is introduced to make it easier to migrate between the current and future versions of the `MemoryRegion` library. It provides a `migrate()` function that can be used to upgrade once a newer version of the library is available.

```motoko
  import MemoryRegion "mo:memory-region/VersionedMemoryRegion";

  stable var memory_region = MemoryRegion.new();
  memory_region := MemoryRegion.migrate(memory_region);
```
For more information on migration, and how these two implementations differ, see the [migration guide](migration.md).

#### Usage

- Store and remove data from a `MemoryRegion`
```motoko

  stable var memory_region = MemoryRegion.new();

  let blob = Blob.fromArray([1, 2, 3, 4]);
  let blob_size = blob.size();

  let address = MemoryRegion.addBlob(memory_region, blob);
  assert blob == MemoryRegion.loadBlob(memory_region, address, blob_size);

  let removed_blob = MemoryRegion.removeBlob(memory_region, address, blob_size);
  assert MemoryRegion.getFreeMemory(memory_region) == [(address, blob_size)];
  assert removed_blob == blob;

  assert MemoryRegion.addBlob(memory_region, blob) == address;
  assert MemoryRegion.getFreeMemory(memory_region) == [];
```

- Using `MemoryRegion` to manage memory internally within a custom data-structure
```motoko

  stable var memory_region = MemoryRegion.new();

  let blob = Blob.fromArray([1, 2, 3, 4]);
  let blob_size = blob.size();

  let address = MemoryRegion.allocate(memory_region, blob_size);

  MemoryRegion.storeBlob(memory_region.region, address, blob_size);

  MemoryRegion.deallocate(memory_region, blob_ptr);
  
```

## Benchmarks
Region vs MemoryRegion

Benchmarking the performance with 10k entries


**Instructions**

|                       |  addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :-------------------- | ---------: | -----------: | ---------------------: | ----------------------: |
| Region                |  9_258_916 |        2_011 |                  2_646 |                   2_958 |
| MemoryRegion          | 11_038_808 |  120_867_124 |             39_782_232 |             141_676_905 |
| VersionedMemoryRegion | 11_379_905 |  121_218_428 |             40_123_743 |             142_028_623 |

**Heap**

|                       | addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :-------------------- | --------: | -----------: | ---------------------: | ----------------------: |
| Region                |     9_152 |        8_904 |                  8_904 |                   8_904 |
| MemoryRegion          |     9_092 |    2_140_716 |              1_688_384 |               2_260_224 |
| VersionedMemoryRegion |     9_092 |    2_140_716 |              1_688_384 |               2_260_224 |