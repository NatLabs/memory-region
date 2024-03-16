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
        bench.rows(["addBlob()", "removeBlob()", "addBlob() reallocation", "Preliminary Step: Sort Addresses", "removeBlob() worst case"]);

        let region : Region = Region.new();
        let memory_region = MemoryRegion.new();
        // let vs_memory_region = VersionedMemoryRegion.new();

        let limit = 10_000;

        let addresses = Buffer.Buffer<Nat>(limit * 2);
        let blobs = Buffer.Buffer<Blob>(limit * 2);

        let order = Buffer.Buffer<Nat>(limit);

        for (i in Iter.range(0, (limit * 2) - 1)) {

            let size = fuzz.nat.randomRange(1, 100);
       
            let blob : Blob = Blob.fromArray(
                Array.tabulate<Nat8>(
                    size,
                    func(i: Nat): Nat8 = Nat8.fromNat(i % 256)
                )
            );

            order.add(i);
            blobs.add(blob);
            
            if (i < limit){
                let address = MemoryRegion.addBlob(memory_region, blob);
                addresses.add(address);
            };
        };

        fuzz.buffer.shuffle(order);

        bench.runner(
            func(row, col) = switch (col, row) {

                case ("Region", "addBlob()") {
                    var address = 0;

                    for (i in Iter.range(0, limit - 1)){
                        let blob = blobs.get(i);
                        let size = blob.size();

                        let capacity = (Nat64.toNat(Region.size(region)) * (2 ** 16));

                        if (capacity < (address + size)) {
                            let size_needed = (address + size) - capacity : Nat;
                            let pages_needed = Utils.div_ceil(size_needed, (2 ** 16));
                            ignore Region.grow(region, Nat64.fromNat(pages_needed));
                        };

                        Region.storeBlob(region, Nat64.fromNat(address), blob);
                        address += size;
                    }
                };

                case ("Region", "removeBlob()" or "addBlob() reallocation" or "removeBlob() worst case" or "Preliminary Step: Sort Addresses"){ };

                case ("MemoryRegion", "addBlob()") {
                    for (i in Iter.range(limit, (limit * 2) - 1)) {
                        let address = MemoryRegion.addBlob(memory_region, blobs.get(i));
                        addresses.add(address);
                    };
                };

                case ("MemoryRegion", "removeBlob()"){ 
                    // remove in random order to avoid the best case scenario of merging all memory blocks into one
                    for (j in Iter.range(0, limit - 1)){
                        let i = order.get(order.size() - j - 1);
                        let address = addresses.get(i);
                        let size = blobs.get(i).size();
                        ignore MemoryRegion.removeBlob(memory_region, address, size);
                    };
                };

                case ("MemoryRegion", "addBlob() reallocation") {
                    for (i in Iter.range(0, limit - 1)) {
                        let blob = blobs.get(i);

                        let j = order.get((order.size() / 2) + i );

                        let address =  MemoryRegion.addBlob(memory_region, blob);
                        blobs.put(j, blob);
                        addresses.put(j, address);
                    };
                };

                case ("MemoryRegion", "Preliminary Step: Sort Addresses") {
                    let blocks = Buffer.Buffer<(Nat, Blob)>(addresses.size());

                    for (i in Iter.range(0, addresses.size() - 1)) {
                        blocks.add((addresses.get(i), blobs.get(i)));
                    };

                    blocks.sort(func(a, b) = Nat.compare(a.0, b.0));

                    for (i in Iter.range(0, blocks.size() - 1)){
                        let (address, blob) = blocks.get(i);
                        addresses.put(i, address);
                        blobs.put(i, blob);
                    };
                };

                case ("MemoryRegion", "removeBlob() worst case"){
                    for (i in Iter.range(0, (limit / 2) - 1)) {
                        let every_2nd_index = i * 2;
                        let address = addresses.get(every_2nd_index);
                        let blob = blobs.get(every_2nd_index);

                        ignore MemoryRegion.removeBlob(memory_region, address, blob.size());
                    };

                    for (i in Iter.range(0, (limit / 2) - 1)) {
                        let every_2nd_index_offset_1 = (i * 2) + 1;
                       
                        let address = addresses.get(every_2nd_index_offset_1);
                        let blob = blobs.get(every_2nd_index_offset_1);

                        ignore MemoryRegion.removeBlob(memory_region, address, blob.size());
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
