// @testmode wasi
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";
import MaxBpTree "mo:augmented-btrees/MaxBpTree";
import Cmp "mo:augmented-btrees/Cmp";
import MaxBpTreeMethods "mo:augmented-btrees/MaxBpTree/Methods";

import Itertools "mo:itertools/Iter";

import MemoryRegion "../src/MemoryRegion";
import Utils "../src/Utils";

func deallocated_size(memory_region: MemoryRegion.MemoryRegion): Nat {
    switch(Itertools.sum(MaxBpTree.vals(memory_region.free_memory), Nat.add)){
        case (?(sum)) { sum };
        case (null) { 0 };
    };
};

suite(
    "MemoryRegion",
    func() {
        let limit = 10_000;

        let fuzzer = Fuzz.fromSeed(0x323);
        let memory_region = MemoryRegion.new();

        let pointers = Buffer.Buffer<MemoryRegion.Pointer>(limit * 2);
        let blobs = Buffer.Buffer<Blob>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let size = fuzzer.nat.randomRange(1, 100);
            let blob = fuzzer.blob.randomBlob(size);
            blobs.add(blob);
        };

        test(
            "allocation and size_info",
            func() {

                var prev_size = 0;

                for (i in Iter.range(0, limit - 1)) {
                    let bytes = fuzzer.nat.randomRange(1, 100);

                    let address = MemoryRegion.allocate(memory_region, bytes) else return assert false;
                    assert address == prev_size;
                    pointers.add((address, bytes));

                    prev_size += bytes;
                };

                let size = prev_size;

                assert MemoryRegion.size(memory_region) == size;
                assert MemoryRegion.allocated(memory_region) == size;
                assert MemoryRegion.deallocated(memory_region) == 0;
                assert MemoryRegion.pages(memory_region) == Utils.div_ceil(size, 64 * 1024);
                assert MemoryRegion.capacity(memory_region) == Utils.div_ceil(size, 64 * 1024) * 64 * 1024;

                assert MemoryRegion.getFreeMemory(memory_region) == [];
                assert pointers.size() == limit;
            },
        );


        test(
            "addBlob()",
            func() {

                let last_pointer = Buffer.last(pointers);
                var expected_address = last_pointer.0 + last_pointer.1;

                for (blob in blobs.vals()) {
                    let address = MemoryRegion.addBlob(memory_region, blob);

                    assert address == expected_address;
                    pointers.add((address, blob.size()));

                    expected_address += blob.size();

                    assert MemoryRegion.loadBlob(memory_region, address, blob.size()) == blob;
                };

                assert MemoryRegion.getFreeMemory(memory_region) == [];
                assert pointers.size() == limit * 2;

            },
        );


        test(
            "deallocate every 2nd memory block",
            func() {
                
                var skipped_address = limit + 1; // avoids starting at 0 because that is the first freed memory block

                var i = 0;
                var max_size = (0, 0);
                var total_deallocated_size = 0;

                while (i < limit) {
                    let (address, size) = pointers.get(i);
                    MemoryRegion.deallocate(memory_region, address, size);

                    assert MaxBpTreeMethods.validate_max_path(memory_region.free_memory, Cmp.Nat);

                    if (size > max_size.1) {
                        max_size := (address, size);
                    };

                    let ?recieved_max = MaxBpTree.maxValue(memory_region.free_memory);

                    if (max_size.1 != recieved_max.1) {
                        Debug.print("free memory " # debug_show MemoryRegion.getFreeMemory(memory_region));
                        Debug.trap("expected != received " # debug_show (max_size, recieved_max));
                    };

                    switch (MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address)) {
                        case (?retrieved_size) {
                            if (not (retrieved_size == size)) {
                                Debug.print("(address, size) " # debug_show (address, size));
                                Debug.print("retrieved " # debug_show (address, retrieved_size));
                                Debug.trap("actual size does not match retrieved size " # debug_show MemoryRegion.getFreeMemory(memory_region));
                            };
                        };
                        case (_) Debug.trap("Did not deallocate memory block");
                    };

                    switch (MaxBpTree.get(memory_region.free_memory, Cmp.Nat, skipped_address)) {
                        case (?_) Debug.trap("Included skipped address in free memory map " # debug_show (address, size));
                        case (_) {};
                    };

                    skipped_address := (address + size);
                    total_deallocated_size += size;

                    assert memory_region.deallocated == total_deallocated_size;
                    i += 2;
                };

                assert deallocated_size(memory_region) == total_deallocated_size;
            },
        );

        test(
            "deallocate and merge adjacent memory blocks",
            func() {
                var start_address = 0;
                var merged_size = pointers.get(0).1;

                var i = 1;

                let ?_max = MaxBpTree.maxValue(memory_region.free_memory);
                var max = _max;
                var total_deallocated_size = memory_region.deallocated;

                while (i < limit) {
                    let (address, size) = pointers.get(i);
                    MemoryRegion.deallocate(memory_region, address, size);
                    assert MaxBpTreeMethods.validate_max_path(memory_region.free_memory, Cmp.Nat);

                    switch (MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address)) {
                        case (?_) Debug.trap("Included the freed memory block instead of merging " # debug_show (address, size) # " with " # debug_show (start_address, merged_size));
                        case (_) {};
                    };

                    let next = pointers.get(i + 1);

                    switch (MaxBpTree.get(memory_region.free_memory, Cmp.Nat, start_address)) {
                        case (?retrieved_size) {
                            if (i + 1 < limit) {
                                if (not (retrieved_size == (merged_size + size + next.1))) {
                                    Debug.print("(prev, curr, next) " # debug_show ((start_address, merged_size), (address, size), next));
                                    Debug.print("retrieved " # debug_show (start_address, retrieved_size));
                                    Debug.trap("Did not merge freed memory block ");
                                };

                                merged_size += size + next.1;
                            } else {
                                if (not (retrieved_size == (merged_size + size))) {
                                    Debug.print("(prev, curr) " # debug_show ((start_address, merged_size), (address, size)));
                                    Debug.print("retrieved " # debug_show (start_address, retrieved_size));
                                    Debug.trap("Did not merge freed memory block ");
                                };

                                merged_size += size;
                            };
                        };
                        case (_) Debug.trap("Did not merge next free memory block with previous one");
                    };

                    if (merged_size > max.1) {
                        max := (start_address, merged_size);
                    };

                    let ?recieved_max = MaxBpTree.maxValue(memory_region.free_memory);

                    if (max.1 != recieved_max.1) {
                        Debug.trap("expected != received " # debug_show (max, recieved_max));
                        assert false;
                    };

                    total_deallocated_size += size;
                    assert memory_region.deallocated == total_deallocated_size;

                    i += 2;
                };

                assert memory_region.deallocated == total_deallocated_size;
                assert deallocated_size(memory_region) == memory_region.deallocated;

                assert MemoryRegion.getFreeMemory(memory_region) == [(start_address, merged_size)];

                // remove the pointers for the memory blocks deallocated in this test
                Buffer.reverse(pointers);

                for (_ in Iter.range(0, limit - 1)) {
                    ignore pointers.removeLast();
                };

                Buffer.reverse(pointers);

                Debug.print("free_memory_block:1 " # debug_show MemoryRegion.getFreeMemory(memory_region));
                Debug.print("max_value:1 " # debug_show MaxBpTree.maxValue(memory_region.free_memory));
            },
        );

        test(
            "removeBlob()",
            func() {
                let order = Buffer.Buffer<Nat>(limit);
                for (i in Iter.range(0, limit - 1)) {
                    order.add(i);
                };
                fuzzer.buffer.shuffle(order);

                assert pointers.size() == limit;

                assert memory_region.deallocated == deallocated_size(memory_region);
                var total_deallocated = memory_region.deallocated;

                for (i in order.vals()) {
                    let (address, size) = pointers.get(i);
                    let expected_blob = blobs.get(i);

                    assert expected_blob.size() == size;

                    assert MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address) == null;
                    let floor = MaxBpTree.getFloor(memory_region.free_memory, Cmp.Nat, address);
                    let ceil = MaxBpTree.getCeiling(memory_region.free_memory, Cmp.Nat, address);

                    let has_prev = switch(floor) {
                        case (?prev) prev.0 + prev.1 == address;
                        case (_) false;
                    };

                    let has_next = switch(ceil) {
                        case (?next) address + size == next.0;
                        case (_) false;
                    };

                    // Debug.print("removing " # debug_show (address, size) );
                    // Debug.print("(has_prev, has_next) " # debug_show (has_prev, has_next));

                    let blob = MemoryRegion.removeBlob(memory_region, address, size);
                    assert MaxBpTreeMethods.validate_max_path(memory_region.free_memory, Cmp.Nat);
                    assert MaxBpTreeMethods.validate_subtree_size(memory_region.free_memory);
                    
                    switch(has_prev, has_next){
                        case (false, false) {
                            let mem_block = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address);
                            assert mem_block == ?(address, size);
                        };
                        case (true, false) {
                            let ?prev = floor else return assert false;
                            // Debug.print("prev " # debug_show prev);
                            let mem_block = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, prev.0);
                            // Debug.print("mem_block " # debug_show mem_block);

                            assert mem_block == ?(prev.0, prev.1 + size);
                        };
                        case (false, true) {
                            let ?next = ceil else return  assert false;
                            // Debug.print("next " # debug_show next);
                            let mem_block = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address);
                            // Debug.print("mem_block " # debug_show mem_block);
                            // Debug.print("next_block " # debug_show MaxBpTree.get(memory_region.free_memory, Cmp.Nat, next.0));

                            assert mem_block == ?(address, size + next.1);
                        };
                        case (true, true) {
                            let ?prev = floor else return  assert false;
                            let ?next = ceil else return  assert false;
                            // Debug.print("prev " # debug_show prev);
                            // Debug.print("next " # debug_show next);
                            let mem_block = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, prev.0);
                            // Debug.print("mem_block " # debug_show mem_block);
                            assert mem_block == ?(prev.0, prev.1 + size + next.1);
                        };
                    };

                    if (not (expected_blob == blob)) {
                        Debug.trap("(expected, received) " # debug_show (expected_blob, blob) # " at index " # debug_show i);
                    };

                    total_deallocated += size;

                    assert memory_region.deallocated == total_deallocated;

                    let total_free_memory = deallocated_size(memory_region);
                    if (not (memory_region.deallocated == total_free_memory)) {
                        Debug.print("mismatch at index " # debug_show i);
                        Debug.print(".deallocated != total_free_memory " # debug_show (memory_region.deallocated, total_free_memory));
                        assert false;
                    };

                };

                Debug.print("free_memory_block:2 " # debug_show MemoryRegion.getFreeMemory(memory_region));

                pointers.clear();
                blobs.clear();
            },
        );


        test(
            "allocate:  reallocate memory blocks",
            func() {
                assert MemoryRegion.getFreeMemory(memory_region).size() == 1;
                let free_memory_block = MemoryRegion.getFreeMemory(memory_region)[0];

                let initial_free_memory_size = free_memory_block.1;

                var expected_address = initial_free_memory_size;

                label _loop for (i in Iter.range(0, limit - 1)) {
                    let size = fuzzer.nat.randomRange(1, 100);

                    expected_address -= size;
                    let new_blob = fuzzer.blob.randomBlob(size);
                    let new_address = MemoryRegion.allocate(memory_region, size);
                    MemoryRegion.storeBlob(memory_region, new_address, new_blob);

                    assert MaxBpTreeMethods.validate_max_path(memory_region.free_memory, Cmp.Nat);

                    if (expected_address != new_address) {
                        Debug.print("expected != new_address " # debug_show (expected_address, new_address));
                        assert false;
                    };

                    pointers.add((new_address, size));
                    blobs.add(new_blob);

                    assert memory_region.deallocated == new_address;
                };
            },
        );

        // test(
        //     "resize()",
        //     func() {
        //         let order = Buffer.Buffer<Nat>(limit);
        //         for (i in Iter.range(0, limit - 1)) {
        //             order.add(i);
        //         };
        //         fuzzer.buffer.shuffle(order);

        //         assert pointers.size() == limit;

        //         assert memory_region.deallocated == deallocated_size(memory_region);
        //         var total_deallocated = memory_region.deallocated;

        //         for (i in order.vals()) {
        //             let (address, size) = pointers.get(i);
        //             let expected_blob = blobs.get(i);

        //             assert expected_blob.size() == size;

        //             assert MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address) == null;
        //             let floor = MaxBpTree.getFloor(memory_region.free_memory, Cmp.Nat, address);
        //             let ceil = MaxBpTree.getCeiling(memory_region.free_memory, Cmp.Nat, address);

        //             let has_prev = switch(floor) {
        //                 case (?prev) prev.0 + prev.1 == address;
        //                 case (_) false;
        //             };

        //             let has_next = switch(ceil) {
        //                 case (?next) address + size == next.0;
        //                 case (_) false;
        //             };

        //             // Debug.print("removing " # debug_show (address, size) );
        //             // Debug.print("(has_prev, has_next) " # debug_show (has_prev, has_next));

        //             let blob = MemoryRegion.removeBlob(memory_region, address, size);
        //             assert MaxBpTreeMethods.validate_max_path(memory_region.free_memory, Cmp.Nat);
        //             assert MaxBpTreeMethods.validate_subtree_size(memory_region.free_memory);
                    
        //             switch(has_prev, has_next){
        //                 case (false, false) {
        //                     let mem_block_size = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address);
        //                     assert mem_block_size == ?size;
        //                 };
        //                 case (true, false) {
        //                     let ?prev = floor else return assert false;
        //                     // Debug.print("prev " # debug_show prev);
        //                     let mem_block_size = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, prev.0);
        //                     // Debug.print("mem_block_size " # debug_show mem_block_size);

        //                     assert mem_block_size == ?(prev.1 + size);
        //                 };
        //                 case (false, true) {
        //                     let ?next = ceil else return  assert false;
        //                     // Debug.print("next " # debug_show next);
        //                     let mem_block_size = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address);
        //                     // Debug.print("mem_block_size " # debug_show mem_block_size);
        //                     // Debug.print("next_block " # debug_show MaxBpTree.get(memory_region.free_memory, Cmp.Nat, next.0));

        //                     assert mem_block_size == ?(size + next.1);
        //                 };
        //                 case (true, true) {
        //                     let ?prev = floor else return  assert false;
        //                     let ?next = ceil else return  assert false;
        //                     // Debug.print("prev " # debug_show prev);
        //                     // Debug.print("next " # debug_show next);
        //                     let mem_block_size = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, prev.0);
        //                     // Debug.print("mem_block_size " # debug_show mem_block_size);
        //                     assert mem_block_size == ?(prev.1 + size + next.1);
        //                 };
        //             };

        //             if (not (expected_blob == blob)) {
        //                 Debug.trap("(expected, received) " # debug_show (expected_blob, blob) # " at index " # debug_show i);
        //             };

        //             total_deallocated += size;

        //             assert memory_region.deallocated == total_deallocated;

        //             let total_free_memory = deallocated_size(memory_region);
        //             if (not (memory_region.deallocated == total_free_memory)) {
        //                 Debug.print("mismatch at index " # debug_show i);
        //                 Debug.print(".deallocated != total_free_memory " # debug_show (memory_region.deallocated, total_free_memory));
        //                 assert false;
        //             };

        //         };

        //         Debug.print("free_memory_block:2 " # debug_show MemoryRegion.getFreeMemory(memory_region));

        //     },
        // );

        test("clear() - deallocate all memory blocks", func(){
            assert MemoryRegion.allocated(memory_region) > 0;

            let prev_memory_info = MemoryRegion.memoryInfo(memory_region);

            MemoryRegion.clear(memory_region);

            assert MemoryRegion.allocated(memory_region) == 0;
            assert MemoryRegion.size(memory_region) == prev_memory_info.size;
            assert MemoryRegion.deallocated(memory_region) == prev_memory_info.size;
            assert MemoryRegion.pages(memory_region) == prev_memory_info.pages;
            assert MemoryRegion.capacity(memory_region) == prev_memory_info.capacity;

            assert MemoryRegion.getFreeMemory(memory_region) == [(0, prev_memory_info.size)];
        });
    },
);
