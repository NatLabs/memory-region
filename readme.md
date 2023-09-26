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

  let blob_ptr = MemoryRegion.storeBlob(memory_region, blob);
  assert blob == MemoryRegion.loadBlob(memory_region, blob_ptr);

  MemoryRegion.removeBlob(memory_region, blob_ptr);
  assert MemoryRegion.getFreeMemory(memory_region) == [blob_ptr];

```

- Using `MemoryRegion` to manage memory internally within a custom data-structure
```motoko
  import Region "mo:base/Region";

  let memory_region = MemoryRegion.new();

  let blob = Blob.fromArray([1, 2, 3, 4]);

  let #ok(ptr) = MemoryRegion.allocate(memory_region, blob.size()) 
    else Debug.trap("failed to allocate memory");

  //     ptr -> (offset, size)
  assert ptr == (0, blob.size());

  Region.storeBlob(memory_region.region, ptr.0, blob);

  assert #ok() == MemoryRegion.deallocate(memory_region, blob_ptr);
  
```