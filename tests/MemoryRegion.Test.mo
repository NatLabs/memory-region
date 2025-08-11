// @testmode wasi
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";
import MaxBpTree "mo:augmented-btrees/MaxBpTree";
import Cmp "mo:augmented-btrees/Cmp";
import MaxBpTreeMethods "mo:augmented-btrees/MaxBpTree/Methods";
import Map "mo:map/Map";
import BpTree "mo:augmented-btrees/BpTree";

import Itertools "mo:itertools/Iter";

import MemoryRegion "../src/MemoryRegion";
import Utils "../src/Utils";

func deallocated_size(memory_region : MemoryRegion.MemoryRegion) : Nat {
    switch (Itertools.sum(MaxBpTree.vals(memory_region.free_memory), Nat.add)) {
        case (?(sum)) { sum };
        case (null) { 0 };
    };
};

let fuzz = Fuzz.fromSeed(0x123);

suite(
    "MemoryRegion",
    func() {
        let limit = 10_000;

        let memory_region = MemoryRegion.new();

        let pointers = Buffer.Buffer<MemoryRegion.MemoryBlock>(limit * 2);
        let blobs = Buffer.Buffer<Blob>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let size = fuzz.nat.randomRange(1, 100);
            let blob = fuzz.blob.randomBlob(size);
            blobs.add(blob);
        };

        test(
            "allocation and size_info",
            func() {

                var prev_size = 0;

                for (i in Iter.range(0, limit - 1)) {
                    let bytes = fuzz.nat.randomRange(1, 3);

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
                    assert MaxBpTreeMethods.validate_max_path(memory_region.free_memory, Cmp.Nat);
                    assert MaxBpTreeMethods.validate_subtree_size(memory_region.free_memory);

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
                    assert MaxBpTreeMethods.validate_subtree_size(memory_region.free_memory);

                    if (size > max_size.1) {
                        max_size := (address, size);
                    };

                    let ?recieved_max = MaxBpTree.maxValue(memory_region.free_memory);

                    if (max_size.1 != recieved_max.1) {
                        // Debug.print("free memory " # debug_show MemoryRegion.getFreeMemory(memory_region));
                        Debug.trap("expected != received " # debug_show (max_size, recieved_max));
                    };

                    switch (MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address)) {
                        case (?retrieved_size) {
                            if (not (retrieved_size == size)) {
                                // Debug.print("(address, size) " # debug_show (address, size));
                                // Debug.print("retrieved " # debug_show (address, retrieved_size));
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
                    assert MaxBpTreeMethods.validate_subtree_size(memory_region.free_memory);

                    switch (MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address)) {
                        case (?_) Debug.trap("Included the freed memory block instead of merging " # debug_show (address, size) # " with " # debug_show (start_address, merged_size));
                        case (_) {};
                    };

                    let next = pointers.get(i + 1);

                    switch (MaxBpTree.get(memory_region.free_memory, Cmp.Nat, start_address)) {
                        case (?retrieved_size) {
                            if (i + 1 < limit) {
                                if (not (retrieved_size == (merged_size + size + next.1))) {
                                    // Debug.print("(prev, curr, next) " # debug_show ((start_address, merged_size), (address, size), next));
                                    // Debug.print("retrieved " # debug_show (start_address, retrieved_size));
                                    Debug.trap("Did not merge freed memory block ");
                                };

                                merged_size += size + next.1;
                            } else {
                                if (not (retrieved_size == (merged_size + size))) {
                                    // Debug.print("(prev, curr) " # debug_show ((start_address, merged_size), (address, size)));
                                    // Debug.print("retrieved " # debug_show (start_address, retrieved_size));
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

                // Debug.print("free_memory_block:1 " # debug_show MemoryRegion.getFreeMemory(memory_region));
                // Debug.print("max_value:1 " # debug_show MaxBpTree.maxValue(memory_region.free_memory));
            },
        );

        test(
            "removeBlob()",
            func() {
                let order = Buffer.Buffer<Nat>(limit);
                for (i in Iter.range(0, limit - 1)) {
                    order.add(i);
                };
                fuzz.buffer.shuffle(order);

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

                    let has_prev = switch (floor) {
                        case (?prev) prev.0 + prev.1 == address;
                        case (_) false;
                    };

                    let has_next = switch (ceil) {
                        case (?next) address + size == next.0;
                        case (_) false;
                    };

                    let is_last_block = address + size == MemoryRegion.size(memory_region);

                    // Debug.print("removing " # debug_show (address, size) );
                    // Debug.print("(has_prev, has_next) " # debug_show (has_prev, has_next));

                    let blob = MemoryRegion.removeBlob(memory_region, address, size);
                    assert MaxBpTreeMethods.validate_max_path(memory_region.free_memory, Cmp.Nat);
                    assert MaxBpTreeMethods.validate_subtree_size(memory_region.free_memory);

                    if (not is_last_block) switch (has_prev, has_next) {
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
                            let ?next = ceil else return assert false;
                            // Debug.print("next " # debug_show next);
                            let mem_block = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address);
                            // Debug.print("mem_block " # debug_show mem_block);
                            // Debug.print("next_block " # debug_show MaxBpTree.get(memory_region.free_memory, Cmp.Nat, next.0));

                            assert mem_block == ?(address, size + next.1);
                        };
                        case (true, true) {
                            let ?prev = floor else return assert false;
                            let ?next = ceil else return assert false;
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

                    // total_deallocated += size;

                    // assert memory_region.deallocated == total_deallocated;

                    let total_free_memory = deallocated_size(memory_region);
                    if (not (memory_region.deallocated == total_free_memory)) {
                        Debug.print("mismatch at index " # debug_show i);
                        Debug.print(".deallocated != total_free_memory " # debug_show (memory_region.deallocated, total_free_memory));
                        assert false;
                    };

                };

                pointers.clear();
                blobs.clear();
            },
        );

        test(
            "allocate:  reallocate memory blocks",
            func() {
                label _loop for (i in Iter.range(0, limit - 1)) {
                    let size = fuzz.nat.randomRange(1, 100);
                    let new_blob = fuzz.blob.randomBlob(size);
                    let new_address = MemoryRegion.allocate(memory_region, size);

                    MemoryRegion.storeBlob(memory_region, new_address, new_blob);

                    pointers.add((new_address, size));
                    blobs.add(new_blob);
                };
            },
        );

        test(
            "resize()",
            func() {
                let order = Buffer.Buffer<Nat>(limit);
                for (i in Iter.range(0, limit - 1)) {
                    order.add(i);
                };
                fuzz.buffer.shuffle(order);

                assert pointers.size() == limit;

                assert memory_region.deallocated == deallocated_size(memory_region);
                var total_deallocated = memory_region.deallocated;
                // Debug.print("free_memory_block:2 " # debug_show MemoryRegion.getFreeMemory(memory_region));

                for (i in order.vals()) {
                    let (address, size) = pointers.get(i);
                    let expected_blob = blobs.get(i);

                    assert expected_blob.size() == size;

                    assert MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address) == null;
                    let floor = MaxBpTree.getFloor(memory_region.free_memory, Cmp.Nat, address);
                    let ceil = MaxBpTree.getCeiling(memory_region.free_memory, Cmp.Nat, address);

                    let has_prev = switch (floor) {
                        case (?prev) prev.0 + prev.1 == address;
                        case (_) false;
                    };

                    let has_next = switch (ceil) {
                        case (?next) address + size == next.0;
                        case (_) false;
                    };

                    let new_size = fuzz.nat.randomRange(1, 2);
                    let new_blob = fuzz.blob.randomBlob(new_size);

                    // Debug.print("replacing " # debug_show (address, size) # " with " # debug_show (new_size));
                    // Debug.print("(has_prev, has_next) " # debug_show (has_prev, has_next));

                    let prev_bytes = MemoryRegion.size(memory_region);
                    let blob = MemoryRegion.loadBlob(memory_region, address, size);
                    let new_address = MemoryRegion.replaceBlob(memory_region, address, size, new_blob);
                    assert MaxBpTreeMethods.validate_max_path(memory_region.free_memory, Cmp.Nat);
                    assert MaxBpTreeMethods.validate_subtree_size(memory_region.free_memory);

                    // Debug.print("total_deallocated before " # debug_show total_deallocated);
                    total_deallocated += size;

                    switch (has_prev, has_next) {
                        case (false, false) {
                            let mem_block_size = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address);

                            // Debug.print("(size, new_size, returned_size) " # debug_show (size, new_size, mem_block_size));

                            if (size == new_size or new_size == size) {
                                assert mem_block_size == null;
                                if (MemoryRegion.size(memory_region) == prev_bytes) total_deallocated -= new_size;
                            } else if (new_size < size) {
                                assert mem_block_size == ?(size - new_size);
                                total_deallocated -= new_size;
                            } else {
                                assert mem_block_size == ?size;
                            };
                        };
                        case (true, false) {
                            let ?prev = floor else return assert false;
                            // Debug.print("prev " # debug_show prev);
                            let mem_block_size = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, prev.0);
                            // Debug.print("mem_block_size " # debug_show mem_block_size);

                            let total_size = prev.1 + size;

                            // Debug.print("(total_size, new_size, returned_size) " # debug_show (total_size, new_size, mem_block_size));

                            if (size == new_size) {
                                assert null == MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address);
                                total_deallocated -= new_size;

                            } else if (new_size == total_size) {
                                assert mem_block_size == null;
                                if (MemoryRegion.size(memory_region) == prev_bytes) total_deallocated -= new_size;
                            } else if (new_size < total_size) {
                                assert mem_block_size == ?(total_size - new_size);
                                total_deallocated -= new_size;
                            } else {
                                assert mem_block_size == ?total_size;
                            };
                        };
                        case (false, true) {
                            let ?next = ceil else return assert false;
                            let total_size = size + next.1;

                            // Debug.print("next " # debug_show next);
                            let mem_block_size = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address);
                            // Debug.print("mem_block_size " # debug_show mem_block_size);
                            // Debug.print("next_block " # debug_show MaxBpTree.get(memory_region.free_memory, Cmp.Nat, next.0));

                            // Debug.print("(total_size, new_size, returned_size) " # debug_show (total_size, new_size, mem_block_size));
                            if (size == new_size or new_size == total_size) {
                                assert mem_block_size == null;
                                if (MemoryRegion.size(memory_region) == prev_bytes) total_deallocated -= new_size;
                            } else if (new_size < total_size) {
                                if (mem_block_size == null) {
                                    // Debug.print(debug_show MaxBpTree.toNodeKeys(memory_region.free_memory));
                                    // Debug.print(debug_show MaxBpTree.toLeafNodes(memory_region.free_memory));
                                };
                                assert mem_block_size == ?(total_size - new_size);
                                total_deallocated -= new_size;
                            } else {
                                assert mem_block_size == ?total_size;
                            };
                        };
                        case (true, true) {
                            let ?prev = floor else return assert false;
                            let ?next = ceil else return assert false;
                            // Debug.print("prev " # debug_show prev);
                            // Debug.print("next " # debug_show next);
                            let mem_block_size = MaxBpTree.get(memory_region.free_memory, Cmp.Nat, prev.0);
                            // Debug.print("mem_block_size " # debug_show mem_block_size);

                            let total_size = prev.1 + size + next.1;
                            // Debug.print("(total_size, new_size, returned_size) " # debug_show (total_size, new_size, mem_block_size));

                            if (size == new_size) {
                                assert null == MaxBpTree.get(memory_region.free_memory, Cmp.Nat, address);
                                total_deallocated -= new_size;
                            } else if (new_size == total_size) {
                                assert mem_block_size == null;
                                if (MemoryRegion.size(memory_region) == prev_bytes) total_deallocated -= new_size;
                            } else if (new_size < total_size) {
                                assert mem_block_size == ?(total_size - new_size);
                                total_deallocated -= new_size;
                            } else {
                                assert mem_block_size == ?total_size;
                            };

                        };
                    };

                    if (not (expected_blob == blob)) {
                        Debug.trap("(expected, received) " # debug_show (expected_blob, blob) # " at index " # debug_show i);
                    };

                    // Debug.print("(memory_region.deallocated, total_deallocated) " # debug_show (memory_region.deallocated, total_deallocated));
                    // assert memory_region.deallocated == total_deallocated;

                    // Debug.print("total_deallocated after" # debug_show total_deallocated);

                    let total_free_memory = deallocated_size(memory_region);
                    if (not (memory_region.deallocated == total_free_memory)) {
                        // Debug.print("mismatch at index " # debug_show i);
                        // Debug.print(".deallocated != total_free_memory " # debug_show (memory_region.deallocated, total_free_memory));
                        assert false;
                    };

                    assert MemoryRegion.loadBlob(memory_region, new_address, new_size) == new_blob;

                };

            },
        );

        test(
            "clear() - deallocate all memory blocks",
            func() {
                assert MemoryRegion.allocated(memory_region) > 0;

                let prev_memory_info = MemoryRegion.memoryInfo(memory_region);

                MemoryRegion.clear(memory_region);

                assert MemoryRegion.allocated(memory_region) == 0;
                assert MemoryRegion.size(memory_region) == prev_memory_info.size;
                assert MemoryRegion.deallocated(memory_region) == prev_memory_info.size;
                assert MemoryRegion.pages(memory_region) == prev_memory_info.pages;
                assert MemoryRegion.capacity(memory_region) == prev_memory_info.capacity;

                assert MemoryRegion.getFreeMemory(memory_region) == [(0, prev_memory_info.size)];
            },
        );

        suite(
            "range operations",
            func() {

                let allocated_address = MemoryRegion.allocate(memory_region, 100_000);
                let deallocated_map = BpTree.new<Nat, Nat>(?32);
                let allocated_map = BpTree.new<Nat, Nat>(?32);

                test(
                    "deallocatedBlocksInRange() and allocatedBlocksInRange()",
                    func() {
                        // Debug.print("allocated address: " # debug_show allocated_address);
                        // Debug.print("freed memory block: " # debug_show MemoryRegion.getFreeMemory(memory_region));

                        if (allocated_address != 0) {
                            ignore BpTree.insert(deallocated_map, Cmp.Nat, 0, allocated_address);
                        };

                        // allocate random memory blocks first, then deallocate some and keep track of both
                        var address = allocated_address;
                        for (i in Itertools.range(0, 1000)) {
                            let size_remaining_allocated = fuzz.nat.randomRange(1, 40);
                            ignore BpTree.insert(allocated_map, Cmp.Nat, address, size_remaining_allocated);
                            address += size_remaining_allocated;

                            let size_to_deallocate = fuzz.nat.randomRange(1, 40);
                            MemoryRegion.deallocate(memory_region, address, size_to_deallocate);
                            ignore BpTree.insert(deallocated_map, Cmp.Nat, address, size_to_deallocate);
                            address += size_to_deallocate;
                        };

                        ignore BpTree.insert(
                            allocated_map,
                            Cmp.Nat,
                            address,
                            Nat.min(
                                (allocated_address + 100_000) - address,
                                MemoryRegion.size(memory_region) - address,
                            ),
                        );

                        let ranges = Array.tabulate<(Nat, Nat)>(
                            100,
                            func(i : Nat) : (Nat, Nat) {
                                let start = fuzz.nat.randomRange(allocated_address - 100, allocated_address + 100_000);

                                let end = fuzz.nat.randomRange(start + 1, Nat.min(start + 10_000, MemoryRegion.size(memory_region)));

                                (start, end);
                            },
                        );

                        // Debug.print("ranges: " # debug_show ranges);

                        for ((start, end) in ranges.vals()) {

                            for ((address, size) in MemoryRegion.deallocatedBlocksInRange(memory_region, start, end)) {
                                let ?deallocated_size = BpTree.get(deallocated_map, Cmp.Nat, address) else {
                                    Debug.trap("Deallocated address not found in deallocated_map " # debug_show (address, size));
                                };

                                if (size != deallocated_size) {
                                    Debug.trap("Deallocated size does not match deallocated_map address (" # debug_show (address) # ") -> " # debug_show (size, deallocated_size));
                                };

                            };

                            let allocated_blocks_to_traverse = Iter.toArray(MemoryRegion.allocatedBlocksInRange(memory_region, start, end));

                            for ((i, (address, size)) in Itertools.enumerate(allocated_blocks_to_traverse.vals())) {
                                if (i == 0) {
                                    let ?floor = BpTree.getFloor(allocated_map, Cmp.Nat, address) else {
                                        Debug.trap("Allocated address not found in allocated_map " # debug_show (address, size));
                                    };

                                    assert floor.0 + floor.1 >= address + size;

                                } else if (i + 1 == allocated_blocks_to_traverse.size()) {
                                    let ?allocated_size = BpTree.get(allocated_map, Cmp.Nat, address) else {
                                        Debug.trap("Allocated address not found in allocated_map " # debug_show (address, size));
                                    };
                                    assert allocated_size >= size;
                                } else {
                                    let ?allocated_size = BpTree.get(allocated_map, Cmp.Nat, address) else {
                                        Debug.trap("Allocated address not found in allocated_map " # debug_show (address, size));
                                    };

                                    if (size != allocated_size) {
                                        Debug.trap("Allocated size does not match allocated_map address (" # debug_show (address) # ") -> " # debug_show (size, allocated_size));
                                    };

                                };

                            };

                        };

                        for ((address, size) in MemoryRegion.deallocatedBlocksInRange(memory_region, 0, MemoryRegion.size(memory_region))) {
                            let ?deallocated_size = BpTree.get(deallocated_map, Cmp.Nat, address) else {
                                Debug.trap("Deallocated address not found in deallocated_map " # debug_show (address, size));
                            };

                            if (size != deallocated_size) {
                                Debug.trap("Deallocated size does not match deallocated_map address (" # debug_show (address) # ") -> " # debug_show (size, deallocated_size));
                            };

                        };

                        for ((address, size) in MemoryRegion.allocatedBlocksInRange(memory_region, 0, MemoryRegion.size(memory_region))) {
                            let ?allocated_size = BpTree.get(allocated_map, Cmp.Nat, address) else {
                                Debug.trap("Allocated address not found in allocated_map " # debug_show (address, size));
                            };

                            if (size != allocated_size) {
                                Debug.trap("Allocated size does not match allocated_map address (" # debug_show (address) # ") -> " # debug_show (size, allocated_size));
                            };
                        };

                    },
                );

                test(
                    "deallocateRange()",
                    func() {

                        let ranges = Array.tabulate<(Nat, Nat)>(
                            100,
                            func(i : Nat) : (Nat, Nat) {
                                let start = fuzz.nat.randomRange(allocated_address - 100, allocated_address + 100_000);
                                let end = fuzz.nat.randomRange(start + 1, Nat.min(start + 10_000, MemoryRegion.size(memory_region)));

                                (start, end);
                            },
                        );

                        for ((start, end) in ranges.vals()) {
                            let allocated_blocks_in_range = Buffer.Buffer<(Nat, Nat)>(1000);

                            var address = start;

                            // Debug.print("range: " # debug_show (start, end));

                            for (freed_memory_block in MemoryRegion.deallocatedBlocksInRange(memory_region, start, end)) {
                                // Debug.print("freed memory block: " # debug_show freed_memory_block);
                                // Debug.print("address: " # debug_show address);
                                // assert address <= freed_memory_block.0;

                                if (address < freed_memory_block.0) {
                                    allocated_blocks_in_range.add(address, freed_memory_block.0 - address);
                                };

                                address := freed_memory_block.0 + freed_memory_block.1;

                            };

                            if (address < end) {
                                allocated_blocks_in_range.add(address, end - address);
                            };

                            // Debug.print("deallocating range: " # debug_show (start, end));

                            MemoryRegion.deallocateRange(memory_region, start, end);

                            // Debug.print("free memory blocks: " # debug_show MemoryRegion.getFreeMemory(memory_region));
                            // Debug.print("allocated blocks in range: " # debug_show Buffer.toArray(allocated_blocks_in_range));

                            for ((address, size) in allocated_blocks_in_range.vals()) {
                                assert MemoryRegion.isFreed(memory_region, address, size) == #ok(true);
                            };

                            //  for ((address, size) in allocated_blocks_in_range.vals()) {
                            //     // re-allocate the freed memory blocks to deallocating the same block in the next iteration
                            //     MemoryRegion.a
                            // };

                        };

                    },
                );
            }

        );

    },
);
