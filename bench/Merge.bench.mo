import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";

import Bench "mo:bench";
import Fuzz "mo:fuzz";

import MemoryRegion  "../src/MemoryRegion";

module {
    public func init() : Bench.Bench {
        let fuzz = Fuzz.Fuzz();

        let bench = Bench.Bench();
        bench.name("MemoryRegion merge performance");
        bench.description("Benchmarking with 10k entries");

        bench.cols(["MemoryRegion"]);
        bench.rows(["no merge (insert)", "merge prev", "merge next", "merge prev and next"]);

        let memory_region = MemoryRegion.new();

        let limit = 10_000;
        let ptrs = Buffer.Buffer<(Nat, Nat)>(limit);

        for (i in Iter.range(0, (limit * 4) - 1)){
            let size = fuzz.nat.randomRange(1, 100);

            let address = MemoryRegion.allocate(memory_region, size);
            let pointer = (address, size);
            ptrs.add(pointer);
        };

        bench.runner(
            func(row, col) = switch (col, row) {

                case ("MemoryRegion", "no merge (insert)") {
                    for (i in Iter.range(0, limit - 1)){
                        let j = (i * 4) + 2;
                        let (address, size) = ptrs.get(j);
                        MemoryRegion.deallocate(memory_region, address, size);
                    };
                };

                case ("MemoryRegion", "merge prev"){
                    for (i in Iter.range(0, limit - 1)){
                        let j = (i * 4) + 1;
                        let (address, size) = ptrs.get(j);
                        MemoryRegion.deallocate(memory_region, address, size);
                    };
                };

                case ("MemoryRegion", "merge next") {
                    for (i in Iter.range(0, limit - 1)){
                        let j = (i * 4) + 3;
                        let (address, size) = ptrs.get(j);
                        MemoryRegion.deallocate(memory_region, address, size);
                    };
                };

                case ("MemoryRegion", "merge prev and next"){
                    for (i in Iter.range(0, limit - 1)){
                        let j = (i * 4);
                        let (address, size) = ptrs.get(j);
                        MemoryRegion.deallocate(memory_region, address, size);
                    };
                };

                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
