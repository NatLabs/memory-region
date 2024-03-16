## Migrating the Memory Region
The `MemoryRegion` library provides two implementations of the MemoryRegion. The regular one and a versioned one.

- Upgrading to a new version and migrating the data in stable memory
  - Install the mops version you want to upgrade to `mops add memory-region@<version>`
  - Include the `migrate()` function in your code or in the post_upgrade() system function
> Note: **Migration is only available for upgrades and not downgrades**


#### Migration from Versioned Module
Migrating with the versioned module is as simple as calling the `migrate()` function on the `MemoryRegion` object. This will upgrade the `MemoryRegion` object to the latest version of the library.

```motoko
  import MemoryRegion "mo:memory-region/VersionedMemoryRegion";

  stable var memory_region = MemoryRegion.new();
  memory_region := MemoryRegion.migrate(memory_region);
```

#### Migration from Regular Module
Migrating with the regular module requires that you store the version of the `MemoryRegion` instance before the upgrade and then restore the instance to the newer version after the upgrade. This is done using the `shareVersion()` and `fromVersion()` functions.

```motoko
  import MemoryRegion "mo:memory-region/MemoryRegion";

  stable var memory_region = MemoryRegion.new();
  stable var memory_region_version = MemoryRegion.shareVersion(memory_region);

  system preupgrade() {
    memory_region_version := MemoryRegion.shareVersion(memory_region);
  }

  system postupgrade() {
    memory_region := MemoryRegion.fromVersion(memory_region_version);
  }

```

### Migration from versions <= `v0.1.1`
- Unfortunatly, the idea of migration was not introduced in the library until `v0.2.0`. If you are using a version <= `v0.1.1`, you will have to indicate the version of the library in your code before you can safely migrate to a newer version.

#### Versioned Module
```motoko
    import MemoryRegion "mo:memory-region/MemoryRegion";
    import VersionedMemoryRegion "mo:memory-region/VersionedMemoryRegion";
    
    stable var prev_memory_region = MemoryRegion.new();

    // indicate the correct version
    stable var memory_region = #v0(prev_memory_region);

    // migrate to the latest version
    memory_region := VersionedMemoryRegion.migrate(memory_region);

```

#### Regular Module

```motoko
  import MemoryRegion "mo:memory-region/MemoryRegion";

  stable var memory_region = MemoryRegion.new();
  stable var memory_region_version = MemoryRegion.shareVersion(memory_region);

  system preupgrade() {
    memory_region_version := MemoryRegion.shareVersion(memory_region);
  }

  system postupgrade() {
    memory_region := MemoryRegion.fromVersion(memory_region_version);
  }
```

### Switching between the Regular and Versioned Module
#### Regular to Versioned Module 
```motoko
    import MemoryRegion "mo:memory-region/MemoryRegion";
    import VersionedMemoryRegion "mo:memory-region/VersionedMemoryRegion";

    stable var regular_memory_region = MemoryRegion.new();

    stable var versioned_memory_region = MemoryRegion.shareVersion(regular_memory_region);

    VersionedMemoryRegion.size(versioned_memory_region); // size -> 0
```

#### Versioned to Regular Module
```motoko
    import MemoryRegion "mo:memory-region/MemoryRegion";
    import VersionedMemoryRegion "mo:memory-region/VersionedMemoryRegion";

    stable var versioned_memory_region = VersionedMemoryRegion.new();

    stable var regular_memory_region = MemoryRegion.fromVersion(versioned_memory_region);

    MemoryRegion.size(regular_memory_region); // size -> 0
```