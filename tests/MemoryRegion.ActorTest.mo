import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Region "mo:base/Region";
import Nat "mo:base/Nat";
import BTree "mo:stableheapbtreemap/BTree";

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

                        var prev_size = 0;
                        var adr = 0;

                        for (i in Iter.range(0, 1000)) {
                            let bytes = fuzzer.nat.randomRange(1, 100);

                            let address = MemoryRegion.allocate(memory_region, bytes) else return assert false;
                            assert address == prev_size;
                            pointers.add((address, bytes));

                            prev_size += bytes;
                        };
                        
                        let size = prev_size;

                        assert MemoryRegion.size_info(memory_region) == {
                            size;
                            allocated = size;
                            deallocated = 0;
                            pages = Utils.div_ceil(size, 64 * 1024);
                            capacity = Utils.div_ceil(size, 64 * 1024) * 64 * 1024;
                        };

                        assert MemoryRegion.getFreeMemory(memory_region) == [];
                    },
                );

                // test(
                //     "deallocation",
                //     func() {

                //         let { size; deallocated =_deallocated } = MemoryRegion.size_info(memory_region);
                //         var deallocated = _deallocated;

                //         let p21 = pointers.get(21);
                //         assert MemoryRegion.deallocate(memory_region, p21.0, p21.1) == #ok();
                //         assert MemoryRegion.getFreeMemory(memory_region) == [p21];
                //         deallocated += p21.1;

                //         let p25 = pointers.get(25);
                //         assert MemoryRegion.deallocate(memory_region, p25.0, p25.1) == #ok();
                //         assert MemoryRegion.getFreeMemory(memory_region) == [p21, p25];
                //         deallocated += p25.1;

                //         let p22 = pointers.get(22);
                //         assert MemoryRegion.deallocate(memory_region, p22.0, p22.1) == #ok();
                //         assert MemoryRegion.getFreeMemory(memory_region) == [(p21.0, p21.1 + p22.1), p25];
                //         deallocated += p22.1;

                //         let p24 = pointers.get(24);
                //         assert MemoryRegion.deallocate(memory_region, p24.0, p24.1) == #ok();
                //         assert MemoryRegion.getFreeMemory(memory_region) == [(p21.0, p21.1 + p22.1), (p24.0, p24.1 + p25.1)];
                //         deallocated += p24.1;

                //         let p23 = pointers.get(23);
                //         assert MemoryRegion.deallocate(memory_region, p23.0, p23.1) == #ok();
                //         assert MemoryRegion.getFreeMemory(memory_region) == [(p21.0, p21.1 + p22.1 + p23.1 + p24.1 + p25.1)];
                //         deallocated += p23.1;

                //         for (i in [25, 24, 23, 22, 21].vals()) {
                //             ignore pointers.remove(i);
                //         };

                //         let pages = Utils.div_ceil(size, 64 * 1024);

                //         let size_info = {
                //             size;
                //             allocated = (size - deallocated) : Nat;
                //             deallocated;
                //             pages;
                //             capacity = pages * 64 * 1024;
                //         };

                //         assert MemoryRegion.size_info(memory_region) == size_info;
                //     },
                // );

                test(
                    "deallocating every 2nd index",
                    func (){
                        let limit = 1000;

                        var skipped_address = 1001; // avoids starting at 0 because that is the first freed memory block

                        for (i in Iter.range(0, limit / 2)) {
                            let every_2nd_index = i * 2;
                            let (address, size) = pointers.get(every_2nd_index);

                            ignore MemoryRegion.deallocate(memory_region, address, size);

                            switch (BTree.get(memory_region.free_memory.addresses, Nat.compare, address)){
                                case (?retrieved_size) {
                                    if (not (retrieved_size == size)) {
                                        Debug.print("(address, size) " # debug_show (address, size));
                                        Debug.print("retrieved " # debug_show (address, retrieved_size));
                                        Debug.trap("actual size does not match retrieved size " # debug_show MemoryRegion.getFreeMemory(memory_region));
                                    }
                                };
                                case (_) Debug.trap("Did not deallocate memory block");
                            };

                            if (BTree.has(memory_region.free_memory.addresses, Nat.compare, skipped_address)){
                                Debug.trap("Included skipped address in free memory map " # debug_show (address, size));
                            };

                            skipped_address := (address + size);
                        };

                        Debug.print("moved on to merge");
                        var start_address = 0;
                        var merged_size = pointers.get(0).1;

                        for (i in Iter.range(0, (limit - 1) / 2)) {
                            let every_2nd_index_from_i_equal_1 = (i * 2) + 1;
                            
                            let (address, size) = pointers.get(every_2nd_index_from_i_equal_1);

                            ignore MemoryRegion.deallocate(memory_region, address, size);

                            if (BTree.has(memory_region.free_memory.addresses, Nat.compare, address)){
                                Debug.trap("Included the freed memory block instead of merging " # debug_show (address, size) # " with " # debug_show (start_address, merged_size));
                            };

                            let next = pointers.get(every_2nd_index_from_i_equal_1 + 1);

                            switch (BTree.get(memory_region.free_memory.addresses, Nat.compare, start_address)){
                                case (?retrieved_size) {
                                    if (not (retrieved_size == (merged_size + size + next.1))) {
                                        Debug.print("(prev, curr, next) " # debug_show ((start_address, merged_size), (address, size), next));
                                        Debug.print("retrieved " # debug_show (start_address, retrieved_size));
                                        Debug.trap("Did not merge freed memory block " # debug_show MemoryRegion.getFreeMemory(memory_region));
                                    }
                                };
                                case (_) Debug.trap("Did not merge next free memory block with previous one");
                            };

                            merged_size += size + next.1;
                        };

                    }
                )
            },
        );
    };

};
