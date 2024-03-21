## Migrating the Memory Region
The `MemoryRegion` library provides two implementations: a regular version and a versioned one. This guide will help you understand the migration process when upgrading to later versions of the library.

#### Key Considerations
- Migration primarily supports upgrades (not downgrades).
- The versioned module streamlines the migration process.
  
### Migration from versions >= `v1.0.0`
#### Versioned Module
Upgrading with the versioned module is straightforward:
  - Install the desired version using `mops add memory-region@<version>`
  - Include the `upgrade()` function in your code or in the `post_upgrade()` system function

```motoko
  import MemoryRegion "mo:memory-region/VersionedMemoryRegion";

  stable var memory_region = MemoryRegion.new();
  memory_region := MemoryRegion.upgrade(memory_region);
```

#### Regular Module
Upgrading with the regular module requires a few extra steps:

- Install the desired version: `mops add memory-region@<version>`
- Initialize two new variables, one to replace the old memory region and another to store the version.
- Use `fromVersioned()` and `toVersioned()` for conversion.
- Annotate the old region with its specific version (`MemoryRegionV<x>`)

- upgrade
```motoko
  import MemoryRegion "mo:memory-region/MemoryRegion";

  // old memory region
  stable var memory_region : MemoryRegion.MemoryRegionV0 = MemoryRegion.new();

  // new memory region
  stable var memory_region_version = MemoryRegion.toVersioned(memory_region); // store the version
  stable var memory_region_v1 = MemoryRegion.fromVersioned(memory_region_version);

  system func preupgrade() {
    // update the version in future upgrades
    memory_region_version := MemoryRegion.toVersioned(memory_region); 
  }

```
Future versions will require additional variables to replace the old one. For this reason, it is adviced to use the versioned module.

### Migration from versions < `v1.0.0`
- Built-in migrations were recently introduced in `v1.0.0` and are not supported in prior versions. It is required to manually indicate the version before you can safely upgrade these versions.

- For `v0.0.1` -> `v0.1.1` the version is `#v0`
- For `v0.2.0`, the version is `#v1`

In future versions, the version name will match the major number of the library version.

#### Versioned Module
```motoko
    import MemoryRegion "mo:memory-region/MemoryRegion";
    import VersionedMemoryRegion "mo:memory-region/VersionedMemoryRegion";
    
    stable var prev_memory_region = MemoryRegion.new();

    // indicate the correct version
    stable var memory_region = #v0(prev_memory_region);

    // upgrade to the latest version
    memory_region := VersionedMemoryRegion.upgrade(memory_region);

```

#### Regular Module

```motoko
  import MemoryRegion "mo:memory-region/MemoryRegion";

  stable var memory_region : MemoryRegionV0 = MemoryRegion.new();
  stable var memory_region_version = #v0(memory_region);

  system preupgrade() {
    memory_region_version := MemoryRegion.toVersioned(memory_region);
  }

  system postupgrade() {
    memory_region := MemoryRegion.fromVersioned(memory_region_version);
  }
```
In addition to this guide, feel free to create an issue in the repository if you have any questions or need further help with migration.

### Switching between the Regular and Versioned Module
#### Regular to Versioned Module 
```motoko
    import MemoryRegion "mo:memory-region/MemoryRegion";
    import VersionedMemoryRegion "mo:memory-region/VersionedMemoryRegion";

    stable var regular_memory_region = MemoryRegion.new();

    stable var versioned_memory_region = MemoryRegion.toVersioned(regular_memory_region);

    let size = VersionedMemoryRegion.size(versioned_memory_region);
```

#### Versioned to Regular Module
```motoko
    import MemoryRegion "mo:memory-region/MemoryRegion";
    import VersionedMemoryRegion "mo:memory-region/VersionedMemoryRegion";

    stable var versioned_memory_region = VersionedMemoryRegion.new();

    stable var regular_memory_region = MemoryRegion.fromVersioned(versioned_memory_region);

    let size = MemoryRegion.size(regular_memory_region);
```