import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Region "mo:base/Region";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";

import Bench "mo:bench";
import Fuzz "mo:fuzz";

import MemoryRegion  "../src/MemoryRegion";
// import VersionedMemoryRegion  "../src/VersionedMemoryRegion";
import Utils "../src/Utils";

module {
    public func init() : Bench.Bench {
        let fuzz = Fuzz.Fuzz();

        let bench = Bench.Bench();
        bench.name("Region vs MemoryRegion");
        bench.description("Benchmarking the performance with 10k entries");

        bench.cols(["Region", "MemoryRegion"]);
        bench.rows(["allocate()", "deallocate()", "allocate() reallocation", "Preliminary Step: Sort Addresses", "deallocate() worst case"]);

        let region : Region = Region.new();
        let memory_region = MemoryRegion.new();
        // let vs_memory_region = VersionedMemoryRegion.new();

        let limit = 10_000;

        let addresses = Buffer.Buffer<Nat>(limit * 2);
        let sizes = Buffer.Buffer<Nat>(limit * 2);

        let order = Buffer.Buffer<Nat>(limit);

        for (i in Iter.range(0, (limit * 2) - 1)) {
            order.add(i);

            let size = fuzz.nat.randomRange(1, limit);
            sizes.add(size);
            
            if (i < limit){
                let address = MemoryRegion.allocate(memory_region, size);
                addresses.add(address);
            };
        };

        fuzz.buffer.shuffle(order);

        bench.runner(
            func(row, col) = switch (col, row) {

                case ("Region", "allocate()") {
                    var address = 0;

                    for (i in Iter.range(0, limit - 1)){
                        let size = sizes.get(i);

                        let capacity = (Nat64.toNat(Region.size(region)) * (2 ** 16));

                        if (capacity < (address + size)) {
                            let size_needed = (address + size) - capacity : Nat;
                            let pages_needed = Utils.div_ceil(size_needed, (2 ** 16));
                            ignore Region.grow(region, Nat64.fromNat(pages_needed));
                        };

                        address += size;
                    }
                };

                case ("Region", "deallocate()" or "allocate() reallocation" or "deallocate() worst case" or "Preliminary Step: Sort Addresses"){ };

                case ("MemoryRegion", "allocate()") {
                    for (i in Iter.range(limit, (limit * 2) - 1)) {
                        let address = MemoryRegion.allocate(memory_region, sizes.get(i));
                        addresses.add(address);
                    };
                };

                case ("MemoryRegion", "deallocate()"){ 
                    // remove in random order to avoid the best case scenario of merging all memory blocks into one
                    for (j in Iter.range(0, limit - 1)){
                        let i = order.get(order.size() - j - 1);
                        let address = addresses.get(i);
                        let size = sizes.get(i);
                        MemoryRegion.deallocate(memory_region, address, size);
                    };
                };

                case ("MemoryRegion", "allocate() reallocation") {
                    for (i in Iter.range(0, limit - 1)) {
                        let size = sizes.get(i);

                        let j = order.get((order.size() / 2) + i );

                        let address =  MemoryRegion.allocate(memory_region, size);
                        sizes.put(j, size);
                        addresses.put(j, address);
                    };
                };

                case ("MemoryRegion", "Preliminary Step: Sort Addresses") {
                    let blocks = Buffer.Buffer<(Nat, Nat)>(addresses.size());

                    for (i in Iter.range(0, addresses.size() - 1)) {
                        blocks.add((addresses.get(i), sizes.get(i)));
                    };

                    blocks.sort(func(a, b) = Nat.compare(a.0, b.0));

                    for (i in Iter.range(0, blocks.size() - 1)){
                        let (address, size) = blocks.get(i);
                        addresses.put(i, address);
                        sizes.put(i, size);
                    };
                };

                case ("MemoryRegion", "deallocate() worst case"){
                    for (i in Iter.range(0, (limit / 2) - 1)) {
                        let every_2nd_index = i * 2;
                        let address = addresses.get(every_2nd_index);
                        let size = sizes.get(every_2nd_index);

                        MemoryRegion.deallocate(memory_region, address, size);
                    };

                    for (i in Iter.range(0, (limit / 2) - 1)) {
                        let every_2nd_index_offset_1 = (i * 2) + 1;
                       
                        let address = addresses.get(every_2nd_index_offset_1);
                        let size = sizes.get(every_2nd_index_offset_1);

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
