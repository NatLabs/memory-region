// @testmode wasi
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";
import MaxBpTree "mo:augmented-btrees/MaxBpTree";
import BpTree "mo:augmented-btrees/BpTree";
import Cmp "mo:augmented-btrees/Cmp";
import MaxBpTreeMethods "mo:augmented-btrees/MaxBpTree/Methods";

import Itertools "mo:itertools/Iter";

import MemoryRegion "../src/MemoryRegion";
import Utils "../src/Utils";

func deallocated_size(memory_region : MemoryRegion.MemoryRegion) : Nat {
    switch (Itertools.sum(MaxBpTree.vals(memory_region.free_memory), Nat.add)) {
        case (?(sum)) { sum };
        case (null) { 0 };
    };
};

func validate_memory_integrity(memory_region : MemoryRegion.MemoryRegion) : Bool {
    // Validate B+ tree integrity
    if (not MaxBpTreeMethods.validate_max_path(memory_region.free_memory, Cmp.Nat)) {
        Debug.print("B+ tree max path validation failed");
        return false;
    };

    if (not MaxBpTreeMethods.validate_subtree_size(memory_region.free_memory)) {
        Debug.print("B+ tree subtree size validation failed");
        return false;
    };

    // Validate memory accounting
    let calculated_deallocated = deallocated_size(memory_region);
    if (calculated_deallocated != MemoryRegion.deallocated(memory_region)) {
        Debug.print("Memory accounting mismatch: calculated=" # debug_show (calculated_deallocated) # ", reported=" # debug_show (MemoryRegion.deallocated(memory_region)));
        return false;
    };

    // Validate that allocated + deallocated <= total size
    let total_accounted = MemoryRegion.allocated(memory_region) + MemoryRegion.deallocated(memory_region);
    if (total_accounted > MemoryRegion.size(memory_region)) {
        Debug.print("Total accounted memory exceeds region size: accounted=" # debug_show (total_accounted) # ", size=" # debug_show (MemoryRegion.size(memory_region)));
        return false;
    };

    true;
};

func stress_test_operations(region : MemoryRegion.MemoryRegion, iterations : Nat) {
    let validation = PointerValidation();
    let memory_map = MemoryBlocksMap<Nat>();

    for (i in Iter.range(0, iterations - 1)) {
        let operation = fuzz.nat.randomRange(0, 3);

        switch (operation) {
            case (0) {
                // Add blob
                let size = fuzz.nat.randomRange(1, 1000);
                let blob = fuzz.blob.randomBlob(size);
                let address = MemoryRegion.addBlob(region, blob);

                validation.recordAllocation(address, size);
                assert memory_map.add((address, size), i);
                assert validate_memory_integrity(region);
            };
            case (1) {
                // Add and immediately remove
                let size = fuzz.nat.randomRange(1, 500);
                let blob = fuzz.blob.randomBlob(size);
                let address = MemoryRegion.addBlob(region, blob);

                let retrieved = MemoryRegion.loadBlob(region, address, size);
                assert retrieved == blob;

                let removed = MemoryRegion.removeBlob(region, address, size);
                assert removed == blob;
                assert validate_memory_integrity(region);
            };
            case (2) {
                // Replace operation
                let old_size = fuzz.nat.randomRange(1, 200);
                let new_size = fuzz.nat.randomRange(1, 800);
                let old_blob = fuzz.blob.randomBlob(old_size);
                let new_blob = fuzz.blob.randomBlob(new_size);

                let address = MemoryRegion.addBlob(region, old_blob);
                let new_address = MemoryRegion.replaceBlob(region, address, old_size, new_blob);

                let retrieved = MemoryRegion.loadBlob(region, new_address, new_size);
                assert retrieved == new_blob;
                assert validate_memory_integrity(region);
            };
            case (_) {}; // No-op
        };

        // Periodic full validation
        if (i % 100 == 0) {
            assert validation.validateNoOverlaps();
            assert memory_map.validateIntegrity();
        };
    };
};

let limit = 10_000;
let fuzz = Fuzz.fromSeed(0xd1ea5f3b4c5e8c1);

let operation_order = Buffer.Buffer<Nat>(limit);
let pointers = Buffer.Buffer<(Nat, Nat)>(limit);
let values = Buffer.Buffer<Blob>(limit);
let equal_size_values = Buffer.Buffer<Blob>(limit);
let greater_size_values = Buffer.Buffer<Blob>(limit);
let less_size_values = Buffer.Buffer<Blob>(limit);

for (i in Iter.range(0, limit - 1)) {
    operation_order.add(i);

    let size_a = fuzz.nat.randomRange(0, 25);
    let blob_a = fuzz.blob.randomBlob(size_a);

    // Less size values: shorter blobs
    less_size_values.add(blob_a);

    let size_b = fuzz.nat.randomRange(size_a, 50);
    let blob_b = fuzz.blob.randomBlob(size_b);

    // Initial values: medium sized blobs
    values.add(blob_b);

    let blob_c = fuzz.blob.randomBlob(size_b);

    // Equal size values: same length as initial
    equal_size_values.add(blob_c);

    let size_d = fuzz.nat.randomRange(size_b, 100);
    let blob_d = fuzz.blob.randomBlob(size_d);

    // Greater size values: longer blobs
    greater_size_values.add(blob_d);

};

fuzz.buffer.shuffle(operation_order);

let region = MemoryRegion.new();

class PointerValidation() {
    let allocated_blocks = Buffer.Buffer<(Nat, Nat)>(limit);

    public func recordAllocation(address : Nat, size : Nat) {
        allocated_blocks.add((address, size));
    };

    public func validateNoOverlaps() : Bool {
        let sorted = Buffer.clone(allocated_blocks);
        sorted.sort(
            func(a : (Nat, Nat), b : (Nat, Nat)) : { #less; #equal; #greater } {
                if (a.0 < b.0) #less else if (a.0 > b.0) #greater else #equal;
            }
        );

        for (i in Iter.range(0, sorted.size() - 2)) {
            let (addr1, size1) = sorted.get(i);
            let (addr2, size2) = sorted.get(i + 1);

            // Check if blocks overlap
            if (addr1 + size1 > addr2 and size1 > 0 and size2 > 0) {
                Debug.print("Overlap detected: Block 1: (" # debug_show (addr1) # ", " # debug_show (size1) # "), Block 2: (" # debug_show (addr2) # ", " # debug_show (size2) # ")");
                return false;
            };
        };
        true;
    };

    public func clear() {
        allocated_blocks.clear();
    };
};

class MemoryBlocksMap<A>() {
    let memory_blocks = BpTree.new<(Nat, Nat), Nat>(null);

    func compare(a : (Nat, Nat), b : (Nat, Nat)) : Int8 {
        if (a.0 < b.0 and a.1 <= b.0) {
            -1;
        } else if (a.0 >= b.1 and a.1 > b.0) {
            1;
        } else {
            0;
        };
    };

    public func add(_block : (Nat, Nat), index : Nat) : Bool {
        if (_block.1 == 0) return true;

        let block = (_block.0, _block.0 + _block.1);

        switch (BpTree.getEntry(memory_blocks, compare, block)) {
            case (?(existing_block, prev_index)) {
                Debug.print("Memory block already exists at index " # debug_show prev_index # ", current index: " # debug_show index);
                Debug.print("Existing block: " # debug_show existing_block # ", New block: " # debug_show block);
                return false;
            };
            case (null) {
                ignore BpTree.insert(memory_blocks, compare, block, index);
                return true;
            };
        };
    };

    public func remove(_block : (Nat, Nat)) : Bool {
        if (_block.1 == 0) return true;

        let block = (_block.0, _block.0 + _block.1);
        switch (BpTree.remove(memory_blocks, compare, block)) {
            case (?_) true;
            case (null) {
                Debug.print("Failed to remove block: " # debug_show block);
                false;
            };
        };
    };

    public func validateIntegrity() : Bool {
        // Check for overlapping blocks
        let entries = BpTree.entries(memory_blocks);
        let blocks = Buffer.Buffer<(Nat, Nat)>(100);

        for ((block, _) in entries) {
            blocks.add(block);
        };

        blocks.sort(
            func(a : (Nat, Nat), b : (Nat, Nat)) : { #less; #equal; #greater } {
                if (a.0 < b.0) #less else if (a.0 > b.0) #greater else #equal;
            }
        );

        for (i in Iter.range(0, blocks.size() - 2)) {
            let (start1, end1) = blocks.get(i);
            let (start2, end2) = blocks.get(i + 1);

            if (end1 > start2) {
                Debug.print("Overlapping blocks detected: (" # debug_show (start1) # ", " # debug_show (end1) # ") and (" # debug_show (start2) # ", " # debug_show (end2) # ")");
                return false;
            };
        };

        true;
    };

    public func size() : Nat {
        BpTree.size(memory_blocks);
    };

    public func clear() {
        BpTree.clear(memory_blocks);
    };
};

suite(
    "MemoryRegion",
    func() {

        test(
            "add Zero Byte (empty) Blobs",
            func() {
                for (i in Iter.range(0, limit - 1)) {
                    let address = MemoryRegion.addBlob(region, "" : Blob);
                    pointers.add(address, 0);
                };

                assert MemoryRegion.size(region) == 0;
                assert MemoryRegion.deallocated(region) == 0;
                assert MemoryRegion.allocated(region) == 0;
                assert MemoryRegion.pages(region) == 0;
                assert MemoryRegion.getFreeMemory(region) == [];
                assert MemoryRegion.capacity(region) == 0;
            },
        );

        test(
            "load empty Blobs",
            func() {
                for (i in Iter.range(0, limit - 1)) {
                    let (address, size) = pointers.get(i);
                    assert ("" : Blob) == MemoryRegion.loadBlob(region, address, size);
                };

                assert MemoryRegion.size(region) == 0;
                assert MemoryRegion.deallocated(region) == 0;
                assert MemoryRegion.allocated(region) == 0;
                assert MemoryRegion.pages(region) == 0;
                assert MemoryRegion.getFreeMemory(region) == [];
                assert MemoryRegion.capacity(region) == 0;
            },
        );

        test(
            "remove Zero Byte (empty) Blobs",
            func() {
                for (i in Iter.range(0, limit - 1)) {
                    let (address, size) = pointers.get(i);
                    assert ("" : Blob) == MemoryRegion.removeBlob(region, address, size);
                };

                assert MemoryRegion.size(region) == 0;
                assert MemoryRegion.deallocated(region) == 0;
                assert MemoryRegion.allocated(region) == 0;
                assert MemoryRegion.pages(region) == 0;
                assert MemoryRegion.getFreeMemory(region) == [];
                assert MemoryRegion.capacity(region) == 0;
            },
        );

        test(
            "addBlob",
            func() {

                for (i in Iter.range(0, limit - 1)) {
                    let blob = values.get(i);
                    let address = MemoryRegion.addBlob(region, blob);
                    let pointer = (address, blob.size());
                    pointers.put(i, pointer);

                    assert MemoryRegion.loadBlob(region, pointer.0, pointer.1) == blob;

                };

            },
        );

        let run_load_blob_test = func() {
            test(
                "loadBlob",
                func() {
                    for (i in Iter.range(0, limit - 1)) {
                        let (address, size) = pointers.get(i);
                        let blob = MemoryRegion.loadBlob(region, address, size);

                        assert (blob == values.get(i));
                    };
                },
            );
        };

        run_load_blob_test();

        test(
            "replaceBlob (same size)",
            func() {

                let size = MemoryRegion.size(region);
                let capacity = MemoryRegion.capacity(region);
                let pages = MemoryRegion.pages(region);
                let deallocated = MemoryRegion.deallocated(region);
                let allocated = MemoryRegion.allocated(region);
                let free_memory = MemoryRegion.getFreeMemory(region);

                for (i in operation_order.vals()) {
                    let (address, prev_size) = pointers.get(i);
                    let new_blob = equal_size_values.get(i);

                    let new_address = MemoryRegion.replaceBlob(region, address, prev_size, new_blob);
                    values.put(i, new_blob);
                    pointers.put(i, (new_address, new_blob.size()));

                    assert MemoryRegion.loadBlob(region, new_address, new_blob.size()) == new_blob;

                };

                assert MemoryRegion.size(region) == size;
                assert MemoryRegion.capacity(region) == capacity;
                assert MemoryRegion.pages(region) == pages;
                assert MemoryRegion.deallocated(region) == deallocated;
                assert MemoryRegion.allocated(region) == allocated;
                assert MemoryRegion.getFreeMemory(region) == free_memory;
            },
        );

        run_load_blob_test();

        test(
            "replaceBlob (larger size)",
            func() {
                let memory_blocks = MemoryBlocksMap<(Nat, Nat)>();

                for (i in operation_order.vals()) {
                    let (address, prev_size) = pointers.get(i);
                    let new_blob = greater_size_values.get(i);

                    // Debug.print("Replacing blob at address " # debug_show (address) # " with new blob of size " # debug_show (new_blob.size()));

                    let new_address = MemoryRegion.replaceBlob(region, address, prev_size, new_blob);
                    values.put(i, new_blob);
                    pointers.put(i, (new_address, new_blob.size()));
                    assert memory_blocks.add((new_address, new_blob.size()), i);

                    assert MemoryRegion.loadBlob(region, new_address, new_blob.size()) == new_blob;

                };
            },
        );

        run_load_blob_test();
        test(
            "replaceBlob (smaller size)",
            func() {
                let memory_blocks = MemoryBlocksMap<(Nat, Nat)>();
                for (i in operation_order.vals()) {
                    let (address, prev_size) = pointers.get(i);
                    let new_blob = less_size_values.get(i);

                    let new_address = MemoryRegion.replaceBlob(region, address, prev_size, new_blob);
                    values.put(i, new_blob);
                    pointers.put(i, (new_address, new_blob.size()));
                    assert memory_blocks.add((new_address, new_blob.size()), i);
                    assert MemoryRegion.loadBlob(region, new_address, new_blob.size()) == new_blob;

                };
            },
        );

        run_load_blob_test();

        // Additional comprehensive test cases for edge cases and potential bugs

        test(
            "Edge Case: Single byte operations",
            func() {
                let single_byte_blob = fuzz.blob.randomBlob(1);
                let address = MemoryRegion.addBlob(region, single_byte_blob);

                assert MemoryRegion.loadBlob(region, address, 1) == single_byte_blob;

                let removed = MemoryRegion.removeBlob(region, address, 1);
                assert removed == single_byte_blob;
            },
        );

        test(
            "Stress Test: Rapid allocation and deallocation",
            func() {
                let stress_limit = 1000;
                let stress_pointers = Buffer.Buffer<(Nat, Nat)>(stress_limit);

                // Rapid allocation
                for (i in Iter.range(0, stress_limit - 1)) {
                    let size = fuzz.nat.randomRange(1, 100);
                    let blob = fuzz.blob.randomBlob(size);
                    let address = MemoryRegion.addBlob(region, blob);
                    stress_pointers.add((address, size));
                };

                // Rapid deallocation in reverse order
                for (i in Iter.range(0, stress_limit - 1)) {
                    let idx = stress_limit - 1 - i;
                    let (address, size) = stress_pointers.get(idx);
                    ignore MemoryRegion.removeBlob(region, address, size);
                };

                // Verify all memory is deallocated
                var total_size = 0;
                for ((_, size) in stress_pointers.vals()) {
                    total_size += size;
                };
                assert MemoryRegion.deallocated(region) >= total_size;
            },
        );

        run_load_blob_test();

        test(
            "Memory Fragmentation Test: Checkerboard pattern",
            func() {
                let pattern_size = 100;
                let pattern_pointers = Buffer.Buffer<(Nat, Nat)>(pattern_size);

                // Allocate blocks
                for (i in Iter.range(0, pattern_size - 1)) {
                    let blob = fuzz.blob.randomBlob(50);
                    let address = MemoryRegion.addBlob(region, blob);
                    pattern_pointers.add((address, blob.size()));
                };

                // Remove every other block (checkerboard pattern)
                for (i in Iter.range(0, pattern_size - 1)) {
                    if (i % 2 == 0) {
                        let (address, size) = pattern_pointers.get(i);
                        ignore MemoryRegion.removeBlob(region, address, size);
                    };

                };

                let pointers_after_removal = Buffer.Buffer<(Nat, Nat)>(pattern_size / 2);

                // Try to allocate in the gaps
                for (i in Iter.range(0, pattern_size / 2 - 1)) {
                    let small_blob = fuzz.blob.randomBlob(25); // Smaller than original
                    let address = MemoryRegion.addBlob(region, small_blob);
                    pointers_after_removal.add((address, small_blob.size()));
                    assert MemoryRegion.loadBlob(region, address, small_blob.size()) == small_blob;
                };

                assert validate_memory_integrity(region);

                // remove all remaining blobs
                for ((address, size) in pointers_after_removal.vals()) {
                    ignore MemoryRegion.removeBlob(region, address, size);
                };

                // Remove every other block (checkerboard pattern)
                for (i in Iter.range(0, pattern_size - 1)) {
                    if (i % 2 == 1) {
                        let (address, size) = pattern_pointers.get(i);
                        ignore MemoryRegion.removeBlob(region, address, size);
                    };

                };
            },
        );

        run_load_blob_test();

        test(
            "Boundary Test: Page boundary operations",
            func() {
                let page_size = 65536; // 64KB

                // Test allocation near page boundaries
                let near_boundary = fuzz.blob.randomBlob(page_size - 10);
                let addr1 = MemoryRegion.addBlob(region, near_boundary);

                let cross_boundary = fuzz.blob.randomBlob(20); // This should cross page boundary
                let addr2 = MemoryRegion.addBlob(region, cross_boundary);

                assert MemoryRegion.loadBlob(region, addr1, near_boundary.size()) == near_boundary;
                assert MemoryRegion.loadBlob(region, addr2, cross_boundary.size()) == cross_boundary;

                // Remove blobs
                let removed1 = MemoryRegion.removeBlob(region, addr1, near_boundary.size());
                assert removed1 == near_boundary;

                let removed2 = MemoryRegion.removeBlob(region, addr2, cross_boundary.size());
                assert removed2 == cross_boundary;

                assert validate_memory_integrity(region);

            },
        );

        run_load_blob_test();

        test(
            "Data corruption detection",
            func() {
                let corruption_test_data = Buffer.Buffer<(Nat, Nat, Blob)>(50);

                // Store known data patterns
                for (i in Iter.range(0, 49)) {
                    let pattern_blob = fuzz.blob.randomBlob(100);
                    let address = MemoryRegion.addBlob(region, pattern_blob);
                    corruption_test_data.add((address, pattern_blob.size(), pattern_blob));
                };

                // Perform many operations that might corrupt data
                for (i in Iter.range(0, 999)) {
                    let temp_blob = fuzz.blob.randomBlob(fuzz.nat.randomRange(10, 200));
                    let temp_address = MemoryRegion.addBlob(region, temp_blob);
                    ignore MemoryRegion.removeBlob(region, temp_address, temp_blob.size());
                };

                // Verify original data is intact
                for ((address, size, original_blob) in corruption_test_data.vals()) {
                    let retrieved_blob = MemoryRegion.loadBlob(region, address, size);
                    if (retrieved_blob != original_blob) {
                        Debug.trap("Data corruption detected!");
                    };
                };

                // remove all test data
                for ((address, size, blob) in corruption_test_data.vals()) {
                    let removed_blob = MemoryRegion.removeBlob(region, address, size);
                    assert removed_blob.size() == size;
                    assert removed_blob == blob;
                };
            },
        );

        run_load_blob_test();

        test(
            "Zero-size edge cases comprehensive",
            func() {
                // Multiple zero-size allocations
                let zero_addresses = Buffer.Buffer<Nat>(100);
                for (i in Iter.range(0, 99)) {
                    let address = MemoryRegion.addBlob(region, fuzz.blob.randomBlob(0));
                    zero_addresses.add(address);
                };

                // Mix with non-zero allocations
                let mixed_blob = fuzz.blob.randomBlob(50);
                let mixed_address = MemoryRegion.addBlob(region, mixed_blob);

                // Verify zero-size reads
                for (address in zero_addresses.vals()) {
                    let blob = MemoryRegion.loadBlob(region, address, 0);
                    assert blob.size() == 0;
                };

                // Verify non-zero read still works
                assert MemoryRegion.loadBlob(region, mixed_address, mixed_blob.size()) == mixed_blob;

                // Remove zero-size blocks
                for (address in zero_addresses.vals()) {
                    let removed = MemoryRegion.removeBlob(region, address, 0);
                    assert removed.size() == 0;
                };

                // remove other blobs
                let removed = MemoryRegion.removeBlob(region, mixed_address, mixed_blob.size());
                assert removed == mixed_blob;

            },
        );

        run_load_blob_test();
        test(
            "Pathological case: Interleaved allocations and deallocations",
            func() {
                let pathological_pointers = Buffer.Buffer<(Nat, Nat)>(200);

                // Phase 1: Allocate many small blocks
                for (i in Iter.range(0, 199)) {
                    let blob = fuzz.blob.randomBlob(10);
                    let address = MemoryRegion.addBlob(region, blob);
                    pathological_pointers.add((address, blob.size()));
                };

                // Phase 2: Remove every 3rd block
                var removed_count = 0;
                for (i in Iter.range(0, 199)) {
                    if (i % 3 == 0) {
                        let (address, size) = pathological_pointers.get(i);
                        ignore MemoryRegion.removeBlob(region, address, size);
                        pathological_pointers.put(i, (0, 0)); // Mark as removed
                        removed_count += 1;
                    };
                };

                let larger_blocks = Buffer.Buffer<(Nat, Nat)>(removed_count);

                // Phase 3: Try to allocate larger blocks in the gaps
                for (i in Iter.range(0, removed_count - 1)) {
                    let blob = fuzz.blob.randomBlob(fuzz.nat.randomRange(5, 15));
                    let address = MemoryRegion.addBlob(region, blob);
                    larger_blocks.add((address, blob.size()));
                    assert MemoryRegion.loadBlob(region, address, blob.size()) == blob;
                };

                // Phase 4: Validate remaining allocations
                for (i in Iter.range(0, 199)) {
                    let (address, size) = pathological_pointers.get(i);
                    if (address != 0 and size != 0) {
                        // Not removed
                        let blob = MemoryRegion.loadBlob(region, address, size);
                        assert blob.size() == size;
                    };
                };

                assert validate_memory_integrity(region);

                // Cleanup: remove all remaining blobs
                for (i in Iter.range(0, 199)) {
                    let (address, size) = pathological_pointers.get(i);
                    if (address != 0 and size != 0) {
                        ignore MemoryRegion.removeBlob(region, address, size);
                    };
                };

                assert validate_memory_integrity(region);

                for ((address, size) in larger_blocks.vals()) {
                    ignore MemoryRegion.removeBlob(region, address, size);
                };

                assert validate_memory_integrity(region);
            },
        );

        run_load_blob_test();

        test(
            "Edge case: Very large number of tiny allocations",
            func() {
                let tiny_count = 5000;
                let tiny_pointers = Buffer.Buffer<(Nat, Nat)>(tiny_count);

                // Allocate many 1-byte blocks
                for (i in Iter.range(0, tiny_count - 1)) {
                    let blob = fuzz.blob.randomBlob(1);
                    let address = MemoryRegion.addBlob(region, blob);
                    tiny_pointers.add((address, 1));

                    if (i % 1000 == 0) {
                        assert validate_memory_integrity(region);
                    };
                };

                // Randomly remove half of them
                fuzz.buffer.shuffle(tiny_pointers);
                for (i in Iter.range(0, tiny_count / 2 - 1)) {
                    let (address, size) = tiny_pointers.get(i);
                    ignore MemoryRegion.removeBlob(region, address, size);
                };

                assert validate_memory_integrity(region);

                // Verify we can still allocate
                let test_blob = fuzz.blob.randomBlob(100);
                let test_address = MemoryRegion.addBlob(region, test_blob);
                assert MemoryRegion.loadBlob(region, test_address, test_blob.size()) == test_blob;

                // remove the remaining tiny blobs
                for (
                    i in Iter.range(
                        tiny_count / 2,
                        tiny_count - 1,
                    )
                ) {
                    let (address, size) = tiny_pointers.get(i);
                    ignore MemoryRegion.removeBlob(region, address, size);
                };

                assert validate_memory_integrity(region);

                // remove the test blob
                ignore MemoryRegion.removeBlob(region, test_address, test_blob.size());
            },
        );

        run_load_blob_test();

        // remove blobs
        test(
            "Cleanup: Remove all blobs",
            func() {
                let region_size = MemoryRegion.size(region);
                for (i in Iter.range(0, limit - 1)) {
                    let (address, size) = pointers.get(i);
                    let removed = MemoryRegion.removeBlob(region, address, size);
                    assert removed.size() == size;
                    assert removed == values.get(i);
                };

                Debug.print("Stats: " # debug_show (MemoryRegion.memoryInfo(region)));

                Debug.print(debug_show MemoryRegion.getFreeMemory(region));

                assert MemoryRegion.size(region) == region_size;
                assert MemoryRegion.deallocated(region) == region_size;
                assert MemoryRegion.allocated(region) == 0;
                assert MemoryRegion.getFreeMemory(region) == [(0, region_size)];
                assert validate_memory_integrity(region);
            },
        );

        test(
            "Random addBlob(), replaceBlob(), and removeBlob() operations",
            func() {

                func run_random_operation<A>(
                    ds : A,
                    operations : [((Nat, (A) -> ()))],
                    run_after_each_iteration : (A) -> (),
                ) {
                    let operation_weights = Array.map(
                        operations,
                        func((weight, _) : (Nat, (A) -> ())) : Nat {
                            weight;
                        },
                    );

                    let ?total_weights = Itertools.sum(operation_weights.vals(), Nat.add) else {
                        Debug.trap("No operations provided");
                    };

                    var nonce = fuzz.nat.randomRange(0, total_weights - 1);
                    var curr = nonce;

                    for ((i, (weight, operation)) in Itertools.enumerate(operations.vals())) {

                        if (curr < weight) {
                            // Debug.print("Running operation " # debug_show (i) # " with weight " # debug_show (weight));
                            operation(ds);
                            run_after_each_iteration(ds);
                            return;
                        };
                        curr -= weight;
                    };

                    Debug.trap("No operation executed, nonce: " # debug_show nonce);

                };

                let values = Buffer.Buffer<Blob>(limit);
                let pointers = Buffer.Buffer<(Nat, Nat)>(limit);

                let add_operation = func(region : MemoryRegion.MemoryRegion) {
                    let blob = fuzz.blob.randomBlob(fuzz.nat.randomRange(0, 25));
                    let address = MemoryRegion.addBlob(region, blob);

                    pointers.add(address, blob.size());
                    values.add(blob);
                };

                func replace_operation(region : MemoryRegion.MemoryRegion) {
                    if (pointers.size() == 0) return;

                    let i = if (pointers.size() <= 1) 0 else fuzz.nat.randomRange(0, pointers.size() - 1);
                    let (address, prev_size) = pointers.get(i);
                    assert MemoryRegion.loadBlob(region, address, prev_size) == values.get(i);

                    let new_blob = fuzz.blob.randomBlob(fuzz.nat.randomRange(0, (prev_size * 2) + 1));
                    let new_address = MemoryRegion.replaceBlob(region, address, prev_size, new_blob);

                    pointers.put(i, (new_address, new_blob.size()));
                    values.put(i, new_blob);
                };

                func remove_operation(region : MemoryRegion.MemoryRegion) {
                    if (pointers.size() == 0) return;

                    let idx = if (pointers.size() <= 1) 0 else fuzz.nat.randomRange(0, pointers.size() - 1);
                    let (address, size) = pointers.get(idx);

                    // Debug.print("freed memory: " # debug_show MemoryRegion.getFreeMemory(region));
                    let removed_blob = MemoryRegion.removeBlob(region, address, size);

                    assert removed_blob.size() == size;
                    assert removed_blob == values.get(idx);

                    assert ?(address, size) == Utils.buffer_swap_remove_last<(Nat, Nat)>(pointers, idx);
                    assert ?removed_blob == Utils.buffer_swap_remove_last<Blob>(values, idx);

                };

                for (i in Iter.range(0, limit * 2)) {
                    // Debug.print("iteration " # debug_show i);

                    run_random_operation<MemoryRegion.MemoryRegion>(
                        region,
                        [(3, add_operation), (5, replace_operation), (2, remove_operation)],
                        func(region : MemoryRegion.MemoryRegion) {
                            if (pointers.size() == 0) add_operation(region);

                            assert validate_memory_integrity(region);
                            for (i in Iter.range(0, pointers.size() - 1)) {
                                let (address, size) = pointers.get(i);
                                let blob = MemoryRegion.loadBlob(region, address, size);

                                assert (blob == values.get(i));
                            };
                        },
                    );

                };

                // cleanup remaining blobs
                for (i in Iter.range(0, pointers.size() - 1)) {
                    remove_operation(region);
                };

                assert validate_memory_integrity(region);

                let region_size = MemoryRegion.size(region);
                assert MemoryRegion.allocated(region) == 0;
                assert MemoryRegion.deallocated(region) == region_size;
                assert MemoryRegion.getFreeMemory(region) == [(0, region_size)];

            },
        );

    },

);
