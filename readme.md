## Memory Region
An abstraction over the native Region type in motoko that allows users to reuse deallocated memory segments

### Usage
```motoko

  import MemoryRegion "mo:memory-region/MemoryRegion";

  let memory_region = MemoryRegion.new();

  let bytes = 100
  let pointer = MemoryRegion.allocate(memory_region, bytes);

  assert pointer == (0, bytes);

  let p2 = MemoryRegion.allocate(memory_region, 300);
  assert p2 == (100, 300);

  let p3 = MemoryRegion.allocate(memory_region, 100);
  assert p3 == (400, 100);

  let p4 = MemoryRegion.allocate(memory_region, 100);
  assert p4 == (500, 100);

  MemoryRegion.deallocate(memory_region, p2);
  

```