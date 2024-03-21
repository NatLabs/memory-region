import MemoryRegionV0_1_1 "mo:memory-region-v0_1_1/MemoryRegion";
import Map "mo:map/Map";
import Debug "mo:base/Debug";

import MemoryRegion "../../src/MemoryRegion";

actor {
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type VersionedMemoryRegion = MemoryRegion.VersionedMemoryRegion;

    stable var memory_region : MemoryRegion.MemoryRegionV0 = MemoryRegionV0_1_1.new();
    stable var memory_region_versions : VersionedMemoryRegion = #v0(memory_region);

    stable var v1_memory_region = MemoryRegion.fromVersioned(memory_region_versions);

    stable let map = Map.new<Nat, Nat>();
    let { nhash } = Map;

    public func addBlob(blob : Blob) : async (Nat) {
        let address = MemoryRegion.addBlob(v1_memory_region, blob);
        ignore Map.put(map, nhash, address, blob.size());

        return address;
    };

    public func getBlob(address : Nat) : async Blob {
        let ?size = Map.get(map, nhash, address) else Debug.trap("Invalid address");
        return MemoryRegion.loadBlob(v1_memory_region, address, size);
    };

    public func removeBlob(address : Nat) : async Blob {
        let ?size = Map.remove(map, nhash, address) else Debug.trap("Invalid address");
        MemoryRegion.removeBlob(v1_memory_region, address, size);
    };

    public func getFreeMemory() : async [(Nat, Nat)] {
        return MemoryRegion.getFreeMemory(v1_memory_region);
    };

    system func preupgrade() {
        // stores the version during the next upgrade
        memory_region_versions := MemoryRegion.toVersioned(v1_memory_region);
    };

};
