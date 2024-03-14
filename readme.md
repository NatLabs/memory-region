## MemoryRegion
MemoryRegion provides an abstraction over Motoko's native [Region](https://internetcomputer.org/docs/current/motoko/main/base/Region/) type, enabling users to reuse deallocated memory blocks efficiently.

## Why Use MemoryRegion?
While Motoko's `Region` type effectively isolates sections of stable memory, it lacks a built-in mechanism for freeing up unused memory blocks. This can result in memory fragmentation, pushing users to develop their own memory management systems. MemoryRegion solves this problem by providing an interface, which extends the `Region` type with a few additional functions for managing memory:
  - `allocate` - allocates a memory block of a given size and returns its address
  - `deallocate` - deallocates a memory block of a given size
  - `addBlob` - allocates enough memory for the given blob, inserts the blob into the `Region` and returns the memory block's address.
  - `removeBlob` - Extracts the blob at the given address from the `Region` and frees up the associated memory block.


## How it works
Internally, the `MemoryRegion` stores data in a `Region`, updating a size counter that keeps track of the total allocated memory, and two btree maps for managing the free memory blocks.
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

- Upgrading to a new version and migrating the data in stable memory
  - Install the mops version you want to upgrade to `mops add memory-region@<version>`
  - Include the `migrate()` function in your code or in the post_upgrade() system function
> Note: Only upgrades are supported. Downgrades are not supported.

```motoko

  stable var memory_region = MemoryRegion.new();
  memory_region := MemoryRegion.migrate(memory_region);
```

## Benchmarks
Region vs MemoryRegion

Benchmarking the performance with 10k entries


**Instructions**

|              |  addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :----------- | ---------: | -----------: | ---------------------: | ----------------------: |
| Region       |  9_260_699 |        ----- |                  ----- |                   ----- |
| MemoryRegion | 11_350_591 |  140_043_805 |             47_321_032 |             168_822_364 |
	

**Heap**

|              | addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :----------- | --------: | -----------: | ---------------------: | ----------------------: |
| Region       |     9_200 |        ----- |                  ----- |                   ----- |
| MemoryRegion |     9_140 |    2_846_132 |              2_489_008 |               2_918_600 |
