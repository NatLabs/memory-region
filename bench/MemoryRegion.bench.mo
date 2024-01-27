import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Region "mo:base/Region";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Prelude "mo:base/Prelude";

import Bench "mo:bench";
import Fuzz "mo:fuzz";
import Itertools "mo:itertools/Iter";

import MemoryRegion  "../src/MemoryRegion";
import Utils "../src/Utils";

module {
    public func init() : Bench.Bench {
        let fuzz = Fuzz.Fuzz();

        let bench = Bench.Bench();
        bench.name("Region vs MemoryRegion");
        bench.description("Benchmarking the performance with 10k entries");

        bench.rows(["Region", "MemoryRegion"]);
        bench.cols(["addBlob()", "removeBlob()", "addBlob() reallocation", "removeBlob() worst case"]);

        let region : Region = Region.new();
        let memory_region = MemoryRegion.new();

        let limit = 10_000;
        let ptrs1 = Buffer.Buffer<(Nat, Nat, Blob)>(limit);
        let ptrs2 = Buffer.Buffer<(Nat, Nat, Blob)>(limit);
        let order = Buffer.Buffer<Nat>(limit);

        var adr1 = 0;
        var adr2 = 0;

        for (i in Iter.range(0, limit - 1)){
            let size1 = fuzz.nat.randomRange(1, 100);
            let size2 = fuzz.nat.randomRange(1, 100);

            let blob1 = Blob.fromArray(
                Array.tabulate<Nat8>(
                    size1,
                    func(i: Nat): Nat8 = Nat8.fromNat(i % 256)
                )
            );

            let blob2 = Blob.fromArray(
                Array.tabulate<Nat8>(
                    size2, 
                    func(i: Nat): Nat8 = Nat8.fromNat(i % 256)
                )
            );

            let ptr1 = (adr1, size1, blob1);
            let ptr2 = (adr2, size2, blob2);

            ptrs1.add(ptr1);
            ptrs2.add(ptr2);
            order.add(i);

            adr1 += size1;
            adr2 += size2;
        };

        fuzz.buffer.shuffle(order);

        bench.runner(
            func(row, col) = switch (row, col) {

                case ("Region", "addBlob()") {

                    for ((address, size, blob) in Itertools.take(ptrs1.vals(), limit)){
                        let capacity = (Nat64.toNat(Region.size(region)) * (2 ** 16));

                        if (capacity < (address + size)) {
                            let size_needed = (address + size) - capacity : Nat;
                            let pages_needed = Utils.div_ceil(size_needed, (2 ** 16));
                            ignore Region.grow(region, Nat64.fromNat(pages_needed));
                        };

                        Region.storeBlob(region, Nat64.fromNat(address), blob);
                    }
                };

                case ("Region", "removeBlob()" or "addBlob() reallocation" or "removeBlob() worst case"){ };

                case ("MemoryRegion", "addBlob()") {
                    for ((address, _, blob) in ptrs1.vals()) {
                        ignore MemoryRegion.addBlob(memory_region, blob);
                    };
                };

                case ("MemoryRegion", "removeBlob()"){
                    for (i in order.vals()) {
                        let (address, size, _) = ptrs1.get(i);
                        ignore MemoryRegion.removeBlob(memory_region, address, size);
                    };
                };

                case ("MemoryRegion", "addBlob() reallocation") {
                    for (i in Iter.range(0, limit - 1)) {
                        let (address, size, blob) = ptrs2.get(i);

                        let new_address = MemoryRegion.addBlob(memory_region, blob);
                        ptrs2.put(i, (new_address, size, blob));
                    };
                };

                case ("MemoryRegion", "removeBlob() worst case"){
                    for (i in Iter.range(0, (limit / 2) - 1)) {
                        let every_2nd_index = i * 2;
                        let (address, size, _) = ptrs2.get(every_2nd_index);

                        ignore MemoryRegion.removeBlob(memory_region, address, size);
                    };

                    for (i in Iter.range(0, (limit / 2) - 1)) {
                        let every_2nd_index_offset_1 = (i * 2) + 1;
                       
                        let (address, size, _) = ptrs2.get(every_2nd_index_offset_1);

                        ignore MemoryRegion.removeBlob(memory_region, address, size);
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
