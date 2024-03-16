import MemoryRegionV0_1_1 "mo:memory-region-v0_1_1/MemoryRegion";
import Map "mo:map/Map";
import Debug "mo:base/Debug";

actor {
    stable let _memory_region = MemoryRegionV0_1_1.new();
    stable var memory_region = #v0(_memory_region);

    stable let map = Map.new<Nat, Nat>();
    let {nhash} = Map;

    public func addBlob(blob: Blob): async (Nat) {
        let address = MemoryRegionV0_1_1.addBlob(_memory_region, blob);
        ignore Map.put(map, nhash, address, blob.size());

        return address;
    };

    public func getBlob(address: Nat): async Blob {
        let ?size = Map.get(map, nhash, address) else Debug.trap("Invalid address");
        return MemoryRegionV0_1_1.loadBlob(_memory_region, address, size);
    };

    public func removeBlob(address: Nat): async Blob {
        let ?size = Map.remove(map, nhash, address) else Debug.trap("Invalid address");
        MemoryRegionV0_1_1.removeBlob(_memory_region, address, size);
    };

    public func getFreeMemory(): async [(Nat, Nat)] {
        return MemoryRegionV0_1_1.getFreeMemory(_memory_region);
    };
}