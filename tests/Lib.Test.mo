// @testmode wasi
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";

import MemoryRegion "../src/MemoryRegion";

suite(
    "MemoryRegion",
    func() {
        test(
            "Test allocation",
            func() {
                let memory_region = MemoryRegion.new();
                let pointers = Buffer.Buffer<MemoryRegion.Pointer>(8);

                let fuzzer = Fuzz.fromTime();

                for (i in Iter.range(0, 100)){
                    let bytes = fuzzer.nat.randomRange(8 * 1024, 1024 ** 3);
                    let #ok(pointer) = MemoryRegion.allocate(memory_region, bytes) else return assert false;
                    pointers.add(pointer);
                };
                
                // assert MemoryRegion.size(memory_region) > 0;
                assert true
            },
        );
    },
);
