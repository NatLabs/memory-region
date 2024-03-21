import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";

import Bench "mo:bench";
import Fuzz "mo:fuzz";

import Migrations "../src/Migrations";
import MemoryRegion "../src/MemoryRegion";
import VersionedMemoryRegion "../src/VersionedMemoryRegion";

module {
    type Buffer<A> = Buffer.Buffer<A>;
    type MemoryRegion = MemoryRegion.MemoryRegion;

    public func init() : Bench.Bench {
        let fuzz = Fuzz.fromSeed(0x7beaf);

        let bench = Bench.Bench();
        bench.name("Region vs MemoryRegion");
        bench.description("Benchmarking the performance with 10k entries");

        bench.cols(["MemoryRegion", "VersionedMemoryRegion"]);
        bench.rows(["allocate()", "deallocate()", "using allocate() to reallocate stored blocks", "Preliminary Step: Sort Addresses", "deallocate() worst case"]);

        let limit = 10_000;

        func populate(memory_region: MemoryRegion, addresses : Buffer<Nat>, sizes : Buffer<Nat>, order : Buffer<Nat>) {
            for (i in Iter.range(0, (limit * 2) - 1)) {
                order.add(i);

                let size = fuzz.nat.randomRange(1, limit);
                sizes.add(size);

                if (i < limit) {

                    let address = MemoryRegion.allocate(memory_region, size);
                    addresses.add(address);
                };
            };

            fuzz.buffer.shuffle(order);
        };

        let memory_region = MemoryRegion.new();
        let addresses = Buffer.Buffer<Nat>(limit * 2);
        let sizes = Buffer.Buffer<Nat>(limit * 2);
        let order = Buffer.Buffer<Nat>(limit * 2);
        populate(memory_region, addresses, sizes, order);

        let vs_memory_region = VersionedMemoryRegion.new();
        let vs_addresses = Buffer.Buffer<Nat>(limit * 2);
        let vs_sizes = Buffer.Buffer<Nat>(limit * 2);
        let vs_order = Buffer.Buffer<Nat>(limit * 2);
        populate(Migrations.getCurrentVersion(vs_memory_region), vs_addresses, vs_sizes, vs_order);


        bench.runner(
            func(row, col) = switch (col, row) {
                case ("MemoryRegion", "allocate()") {
                    for (i in Iter.range(limit, (limit * 2) - 1)) {
                        let address = MemoryRegion.allocate(memory_region, sizes.get(i));
                        addresses.add(address);
                    };
                };
                case ("MemoryRegion", "deallocate()") {
                    // remove in random order to avoid the best case scenario of merging all memory blocks into one
                    for (j in Iter.range(0, limit - 1)) {
                        let i = order.get(order.size() - j - 1);
                        let address = addresses.get(i);
                        let size = sizes.get(i);
                        MemoryRegion.deallocate(memory_region, address, size);
                    };
                };
                case ("MemoryRegion", "using allocate() to reallocate stored blocks") {
                    for (i in Iter.range(0, limit - 1)) {
                        let size = sizes.get(i);

                        let j = order.get((order.size() / 2) + i);

                        let address = MemoryRegion.allocate(memory_region, size);
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

                    for (i in Iter.range(0, blocks.size() - 1)) {
                        let (address, size) = blocks.get(i);
                        addresses.put(i, address);
                        sizes.put(i, size);
                    };
                };
                case ("MemoryRegion", "deallocate() worst case") {
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

                // VersionedMemoryRegion
                case ("VersionedMemoryRegion", "allocate()") {
                    for (i in Iter.range(limit, (limit * 2) - 1)) {
                        let address = VersionedMemoryRegion.allocate(vs_memory_region, sizes.get(i));
                        vs_addresses.add(address);
                    };
                };
                case ("VersionedMemoryRegion", "deallocate()") {
                    // remove in random order to avoid the best case scenario of merging all memory blocks into one
                    for (j in Iter.range(0, limit - 1)) {
                        let i = vs_order.get(vs_order.size() - j - 1);
                        let address = vs_addresses.get(i);
                        let size = vs_sizes.get(i);
                        VersionedMemoryRegion.deallocate(vs_memory_region, address, size);
                    };
                };
                case ("VersionedMemoryRegion", "using allocate() to reallocate stored blocks") {
                    for (i in Iter.range(0, limit - 1)) {
                        let size = vs_sizes.get(i);

                        let j = vs_order.get((vs_order.size() / 2) + i);

                        let address = VersionedMemoryRegion.allocate(vs_memory_region, size);
                        vs_sizes.put(j, size);
                        vs_addresses.put(j, address);
                    };
                };
                case ("VersionedMemoryRegion", "Preliminary Step: Sort Addresses") {
                    let blocks = Buffer.Buffer<(Nat, Nat)>(vs_addresses.size());

                    for (i in Iter.range(0, vs_addresses.size() - 1)) {
                        blocks.add((vs_addresses.get(i), vs_sizes.get(i)));
                    };

                    blocks.sort(func(a, b) = Nat.compare(a.0, b.0));

                    for (i in Iter.range(0, blocks.size() - 1)) {
                        let (address, size) = blocks.get(i);
                        vs_addresses.put(i, address);
                        vs_sizes.put(i, size);
                    };
                };
                case ("VersionedMemoryRegion", "deallocate() worst case") {
                    for (i in Iter.range(0, (limit / 2) - 1)) {
                        let every_2nd_index = i * 2;
                        let address = vs_addresses.get(every_2nd_index);

                        let size = vs_sizes.get(every_2nd_index);

                        VersionedMemoryRegion.deallocate(vs_memory_region, address, size);
                    };

                    for (i in Iter.range(0, (limit / 2) - 1)) {
                        let every_2nd_index_offset_1 = (i * 2) + 1;

                        let address = vs_addresses.get(every_2nd_index_offset_1);
                        let size = vs_sizes.get(every_2nd_index_offset_1);

                        VersionedMemoryRegion.deallocate(vs_memory_region, address, size);
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
