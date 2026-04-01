// @testmode wasi
import Iter "mo:base@0.14.13/Iter";
import Debug "mo:base@0.14.13/Debug";
import Nat "mo:base@0.14.13/Nat";
import Buffer "mo:base@0.14.13/Buffer";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";
import MaxBpTree "mo:augmented-btrees@0.9.0/MaxBpTree";
import MaxBpTreeMethods "mo:augmented-btrees@0.9.0/MaxBpTree/Methods";
import Cmp "mo:augmented-btrees@0.9.0/Cmp";

import FreeMemory "../src/FreeMemory";

// Validates that the MaxBpTree's max tracking is correct:
// For every branch, branch.4[MAX] must equal the max of all its children,
// AND the reported maxValue must actually be the maximum in the tree.
func validate_true_max(free_memory : FreeMemory.FreeMemory) : Bool {
    // get the reported max
    let ?reported = MaxBpTree.maxValue(free_memory) else return true; // empty tree is fine

    // scan ALL entries to find the true max
    var true_max : Nat = 0;
    for ((addr, size) in MaxBpTree.entries(free_memory)) {
        if (size > true_max) true_max := size;
    };

    if (reported.1 != true_max) {
        Debug.print("validate_true_max FAILED:");
        Debug.print("  reported maxValue = " # debug_show reported);
        Debug.print("  actual max size   = " # debug_show true_max);
        false
    } else {
        true
    }
};

suite(
    "FreeMemory max-value invariant",
    func() {

        // -----------------------------------------------------------------------
        // Test 1: alternating reallocate + deallocate with mixed sizes
        // Simulates the pattern that causes violations in MemoryBTree when
        // multiple variable-size allocation types share the same region.
        // -----------------------------------------------------------------------
        test(
            "reallocate and deallocate with mixed sizes preserves max invariant",
            func() {
                let fuzz = Fuzz.fromSeed(0xdeadbeef);
                let fm = FreeMemory.new();

                // Simulate a region: track next free address
                var next_addr : Nat = 64; // header offset

                // Helper: "allocate" a block by inserting it as free, then using reallocate
                // We pre-populate the free pool with many blocks of mixed sizes.

                // Phase 1: populate free pool with blocks of 3 different size classes
                // (mimicking leaf entries 15-45 bytes, branch keys 2-30 bytes,
                //  prefix keys 2-15 bytes all in the same region)
                let live_blocks = Buffer.Buffer<(Nat, Nat)>(200); // (address, size)

                // Insert 300 blocks of varied sizes into the free pool
                var addr = next_addr;
                for (i in Iter.range(0, 299)) {
                    // 3 size classes: small (2-15), medium (17-32), large (34-50)
                    let size_class = i % 3;
                    let size = if (size_class == 0) {
                        fuzz.nat.randomRange(2, 15)
                    } else if (size_class == 1) {
                        fuzz.nat.randomRange(17, 32)
                    } else {
                        fuzz.nat.randomRange(34, 50)
                    };
                    ignore MaxBpTree.insert(fm, Cmp.Nat, Cmp.Nat, addr, size);
                    addr += size + 5; // +5 gap to avoid auto-merging in FreeMemory
                };

                // Check invariant after initial population
                assert validate_true_max(fm);
                assert MaxBpTreeMethods.validate_max_path(fm, Cmp.Nat);

                // Phase 2: mixed reallocate + deallocate operations
                // This tests the exact pattern FreeMemory uses: reallocate shrinks the
                // max block (via replaceMaxValue), and remove/insert happen concurrently.
                var iteration = 0;
                while (iteration < 500) {
                    // Reallocate: get max block and shrink it
                    switch (MaxBpTree.maxValue(fm)) {
                        case (null) {};
                        case (?(max_addr, max_size)) {
                            let alloc_size = if (max_size <= 2) 1 else fuzz.nat.randomRange(1, Nat.min(max_size - 1, 30));
                            let split_size = max_size - alloc_size : Nat;

                            if (split_size == 0) {
                                ignore MaxBpTree.remove(fm, Cmp.Nat, Cmp.Nat, max_addr);
                            } else {
                                // shrink the max block (replaceMaxValue)
                                ignore MaxBpTree.replaceMaxValue(fm, Cmp.Nat, Cmp.Nat, split_size);
                                let alloc_addr = max_addr + split_size;
                                live_blocks.add((alloc_addr, alloc_size));
                            };

                            if (not validate_true_max(fm)) {
                                Debug.print("invariant violated after reallocate at iteration " # debug_show iteration);
                                assert false;
                            };
                            if (not MaxBpTreeMethods.validate_max_path(fm, Cmp.Nat)) {
                                Debug.print("max_path invalid after reallocate at iteration " # debug_show iteration);
                                assert false;
                            };
                        };
                    };

                    // Randomly free a live block back into the pool
                    let nb = live_blocks.size();
                    if (nb >= 2) {
                        let idx = if (nb == 2) 0 else fuzz.nat.randomRange(0, nb - 2);
                        let (free_addr, free_size) = live_blocks.get(idx);
                        live_blocks.put(idx, live_blocks.get(nb - 1));
                        ignore live_blocks.removeLast();

                        // deallocate: insert back into free pool (no merging for simplicity)
                        ignore MaxBpTree.insert(fm, Cmp.Nat, Cmp.Nat, free_addr, free_size);

                        if (not validate_true_max(fm)) {
                            Debug.print("invariant violated after deallocate at iteration " # debug_show iteration);
                            assert false;
                        };
                        if (not MaxBpTreeMethods.validate_max_path(fm, Cmp.Nat)) {
                            Debug.print("max_path invalid after deallocate at iteration " # debug_show iteration);
                            assert false;
                        };
                    };

                    // Randomly remove a free block (simulates reclaim_and_assign_new_size removing next)
                    let ts = MaxBpTree.size(fm);
                    if (ts >= 10 and fuzz.nat.randomRange(0, 4) == 0) {
                        // pick a random entry to remove (avoiding index 0 to keep min safe)
                        let remove_rank = fuzz.nat.randomRange(1, ts - 2);
                        let (rm_addr, _) = MaxBpTree.getFromIndex(fm, remove_rank);
                        ignore MaxBpTree.remove(fm, Cmp.Nat, Cmp.Nat, rm_addr);

                        if (not validate_true_max(fm)) {
                            Debug.print("invariant violated after random remove at iteration " # debug_show iteration);
                            assert false;
                        };
                        if (not MaxBpTreeMethods.validate_max_path(fm, Cmp.Nat)) {
                            Debug.print("max_path invalid after random remove at iteration " # debug_show iteration);
                            assert false;
                        };
                    };

                    iteration += 1;
                };
            },
        );

        // -----------------------------------------------------------------------
        // Test 2: replaceMaxValue followed by remove triggers max-tracking invariant
        // -----------------------------------------------------------------------
        test(
            "replaceMaxValue followed by remove preserves max invariant",
            func() {
                let fuzz = Fuzz.fromSeed(0xcafebabe);
                let fm = FreeMemory.new();

                // Insert entries with sizes that will create a large tree
                var addr = 64;
                for (i in Iter.range(0, 199)) {
                    let size = fuzz.nat.randomRange(1, 100);
                    ignore MaxBpTree.insert(fm, Cmp.Nat, Cmp.Nat, addr, size);
                    addr += size + 3;
                };

                assert validate_true_max(fm);
                assert MaxBpTreeMethods.validate_max_path(fm, Cmp.Nat);

                // Repeatedly: replaceMaxValue (shrink max) then remove a non-max entry
                for (round in Iter.range(0, 199)) {
                    // shrink the current max
                    switch (MaxBpTree.maxValue(fm)) {
                        case (null) {};
                        case (?(max_addr, max_size)) {
                            let new_size = Nat.max(1, max_size / 2);
                            ignore MaxBpTree.replaceMaxValue(fm, Cmp.Nat, Cmp.Nat, new_size);
                        };
                    };

                    if (not validate_true_max(fm)) {
                        Debug.print("FAIL after replaceMaxValue at round " # debug_show round);
                        assert false;
                    };

                    // remove the entry with the smallest key (min of the tree)
                    switch (MaxBpTree.min(fm)) {
                        case (null) {};
                        case (?(min_addr, _)) {
                            ignore MaxBpTree.remove(fm, Cmp.Nat, Cmp.Nat, min_addr);
                        };
                    };

                    if (not validate_true_max(fm)) {
                        Debug.print("FAIL after remove at round " # debug_show round);
                        assert false;
                    };
                };
            },
        );

    },
);
