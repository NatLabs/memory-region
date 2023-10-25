## Memory Region
An abstraction over the native Region type in motoko that allows users to reuse deallocated memory segments

### Usage
- Import memory region
```motoko
  import MemoryRegion "mo:memory-region/MemoryRegion";
```

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