import MemoryRegionV0_1_1 "mo:memory-region-v0_1_1/MemoryRegion";
import Map "mo:map/Map";
import Debug "mo:base/Debug";

import MemoryRegion "../../src/VersionedMemoryRegion";

actor {
    type MemoryRegion = MemoryRegion.VersionedMemoryRegion;

    stable let _memory_region = MemoryRegionV0_1_1.new();
    stable var memory_region : MemoryRegion = #v0(_memory_region);
    memory_region := MemoryRegion.upgrade(memory_region);

    stable let map = Map.new<Nat, Nat>();
    let {nhash} = Map;

    public func addBlob(blob: Blob): async (Nat) {
        let address = MemoryRegion.addBlob(memory_region, blob);
        ignore Map.put(map, nhash, address, blob.size());

        return address;
    };

    public func getBlob(address: Nat): async Blob {
        let ?size = Map.get(map, nhash, address) else Debug.trap("Invalid address");
        return MemoryRegion.loadBlob(memory_region, address, size);
    };

    public func removeBlob(address: Nat): async Blob {
        let ?size = Map.remove(map, nhash, address) else Debug.trap("Invalid address");
        MemoryRegion.removeBlob(memory_region, address, size);
    };

    public func getFreeMemory(): async [(Nat, Nat)] {
        return MemoryRegion.getFreeMemory(memory_region);
    };

}