import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Region "mo:base/Region";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";

import MemoryRegion "../src/MemoryRegion";
import Utils "../src/Utils";

module {
    public func actor_test() : async () {
        suite(
            "MemoryRegion",
            func() {
                test(
                    "allocation",
                    func() {
                        let memory_region = MemoryRegion.new();
                        let pointers = Buffer.Buffer<MemoryRegion.Pointer>(8);

                        let fuzzer = Fuzz.fromTime();

                        var size = 0;
                        for (i in Iter.range(0, 100)) {
                            let bytes = fuzzer.nat.randomRange(8 * 1024, 1024 ** 3);
                            size += bytes;
                            let #ok(pointer) = MemoryRegion.allocate(memory_region, bytes) else return assert false;
                            pointers.add(pointer);
                        };

                        assert MemoryRegion.size_info(memory_region) == {
                            size;
                            allocated = size;
                            deallocated = 0;
                            pages = Utils.div_ceil(size, 64 * 1024);
                            capacity = Utils.div_ceil(size, 64 * 1024) * 64 * 1024;
                        };

                        for (i in [21, 25, 22, 24, 23].vals()) {
                            let pointer = pointers.remove(i);
                            ignore MemoryRegion.deallocate(memory_region, pointer);

                            Debug.print("Deallocated: \n" # debug_show MemoryRegion.get_free_memory(memory_region));
                        };

                        assert true;
                    },
                );
            },
        );
    };
};
