import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Region "mo:base/Region";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";

import MemoryRegion "../src/MemoryRegion";
import Utils "../src/Utils";

actor {
    public func actor_test() : async () {
        suite(
            "MemoryRegion",
            func() {

                let memory_region = MemoryRegion.new();
                let pointers = Buffer.Buffer<MemoryRegion.Pointer>(8);

                test(
                    "allocation and size_info",
                    func() {

                        let fuzzer = Fuzz.fromTime();

                        var size = 0;

                        for (i in Iter.range(0, 100)) {
                            let bytes = fuzzer.nat.randomRange(8 * 1024, 1024 ** 2);
                            size += bytes;

                            let address = MemoryRegion.allocate(memory_region, bytes) else return assert false;
                            pointers.add((address, bytes));
                        };

                        assert MemoryRegion.size_info(memory_region) == {
                            size;
                            allocated = size;
                            deallocated = 0;
                            pages = Utils.div_ceil(size, 64 * 1024);
                            capacity = Utils.div_ceil(size, 64 * 1024) * 64 * 1024;
                        };
                    },
                );

                test(
                    "deallocation",
                    func() {

                        let { size; deallocated =_deallocated } = MemoryRegion.size_info(memory_region);
                        var deallocated = _deallocated;

                        let p21 = pointers.get(21);
                        assert MemoryRegion.deallocate(memory_region, p21.0, p21.1) == #ok();
                        assert MemoryRegion.getFreeMemory(memory_region) == [p21];
                        deallocated += p21.1;

                        let p25 = pointers.get(25);
                        assert MemoryRegion.deallocate(memory_region, p25.0, p25.1) == #ok();
                        assert MemoryRegion.getFreeMemory(memory_region) == [p21, p25];
                        deallocated += p25.1;

                        let p22 = pointers.get(22);
                        assert MemoryRegion.deallocate(memory_region, p22.0, p22.1) == #ok();
                        assert MemoryRegion.getFreeMemory(memory_region) == [(p21.0, p21.1 + p22.1), p25];
                        deallocated += p22.1;

                        let p24 = pointers.get(24);
                        assert MemoryRegion.deallocate(memory_region, p24.0, p24.1) == #ok();
                        assert MemoryRegion.getFreeMemory(memory_region) == [(p21.0, p21.1 + p22.1), (p24.0, p24.1 + p25.1)];
                        deallocated += p24.1;

                        let p23 = pointers.get(23);
                        assert MemoryRegion.deallocate(memory_region, p23.0, p23.1) == #ok();
                        assert MemoryRegion.getFreeMemory(memory_region) == [(p21.0, p21.1 + p22.1 + p23.1 + p24.1 + p25.1)];
                        deallocated += p23.1;

                        for (i in [21, 25, 22, 24, 23].vals()) {
                            ignore pointers.remove(i);
                        };

                        let pages = Utils.div_ceil(size, 64 * 1024);

                        let size_info = {
                            size;
                            allocated = (size - deallocated) : Nat;
                            deallocated;
                            pages;
                            capacity = pages * 64 * 1024;
                        };

                        assert MemoryRegion.size_info(memory_region) == size_info
                    },
                );
            },
        );
    };

};
