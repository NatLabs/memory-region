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

// Validates that the reported maxValue() actually equals the true max.
func validate_true_max(fm : FreeMemory.FreeMemory) : Bool {
    let ?reported = MaxBpTree.maxValue(fm) else return true;

    var true_max : Nat = 0;
    for ((_, size) in MaxBpTree.entries(fm)) {
        if (size > true_max) true_max := size;
    };

    if (reported.1 != true_max) {
        Debug.print("validate_true_max FAILED:");
        Debug.print("  reported = " # debug_show reported);
        Debug.print("  actual   = " # debug_show true_max);
        Debug.print("  all entries: " # debug_show FreeMemory.toArray(fm));
        false
    } else {
        true
    }
};

func check(fm : FreeMemory.FreeMemory, label_ : Text) {
    if (not validate_true_max(fm)) {
        Debug.print("FAIL at: " # label_);
        assert false;
    };
    if (not MaxBpTreeMethods.validate_max_path(fm, Cmp.Nat)) {
        Debug.print("validate_max_path FAILED at: " # label_);
        assert false;
    };
};

suite(
    "FreeMemory merging + reallocate invariant",
    func() {

        // -----------------------------------------------------------------------
        // Test: simulates MemoryRegion's pattern:
        //   allocate many blocks
        //   deallocate (with adjacent-block merging via reclaim_and_assign_new_size)
        //   reallocate (from free pool)
        //   resize (reclaim + reallocate)
        // -----------------------------------------------------------------------
        test(
            "reclaim_and_assign_new_size with merging preserves max invariant",
            func() {
                let fuzz = Fuzz.fromSeed(0xdeadbeef);
                let fm = FreeMemory.new();

                // Simulate a flat block of memory with blocks of 3 size classes
                // (address, size) pairs — all ADJACENT (no gaps between blocks)
                // Building a contiguous memory layout like MemoryBTree uses.
                // Block sizes cycle: small(2-15), medium(17-32), large(34-50)

                type Block = { address : Nat; size : Nat; var live : Bool };
                let blocks = Buffer.Buffer<Block>(300);

                var cursor : Nat = 64;
                for (i in Iter.range(0, 299)) {
                    let size_class = i % 3;
                    let size = if (size_class == 0) {
                        fuzz.nat.randomRange(3, 15)
                    } else if (size_class == 1) {
                        fuzz.nat.randomRange(17, 32)
                    } else {
                        fuzz.nat.randomRange(34, 50)
                    };
                    blocks.add({ address = cursor; size; var live = true });
                    cursor += size;
                };

                // Initially all blocks are LIVE (allocated), free memory is empty
                check(fm, "initial state");

                // Helper: get a live block index, any one
                func pick_live() : ?Nat {
                    let nb = blocks.size();
                    var tries = 0;
                    while (tries < 50) {
                        let i = if (nb <= 1) 0 else fuzz.nat.randomRange(0, nb - 2);
                        if (blocks.get(i).live) return ?i;
                        tries += 1;
                    };
                    null
                };

                var iteration = 0;
                while (iteration < 1000) {
                    // === Step A: Deallocate a live block (reclaim_and_assign_new_size null) ===
                    // This triggers merging with adjacent free blocks.
                    let n = blocks.size();
                    var live_idx_opt : ?Nat = null;
                    var tries = 0;
                    while (tries < 20 and live_idx_opt == null) {
                        let i = if (n <= 1) 0 else fuzz.nat.randomRange(0, n - 2);
                        if (blocks.get(i).live) live_idx_opt := ?i;
                        tries += 1;
                    };
                    switch (live_idx_opt) {
                        case (?live_idx) {
                            let b = blocks.get(live_idx);
                            let result = FreeMemory.reclaim_and_assign_new_size(fm, b.address, b.size, null);
                            assert result == null;
                            b.live := false;
                            check(fm, "after dealloc " # debug_show (b.address, b.size) # " iter=" # debug_show iteration);
                        };
                        case (null) {};
                    };

                    // === Step B: Reallocate from the free pool ===
                    // Pre-check: assert all free blocks don't overlap live blocks
                    for ((free_addr, free_size) in MaxBpTree.entries(fm)) {
                        for (b in blocks.vals()) {
                            if (b.live) {
                                let overlap = not (free_addr + free_size <= b.address or b.address + b.size <= free_addr);
                                if (overlap) {
                                    Debug.print("PRE-REALLOC: free block overlaps live block at iter=" # debug_show iteration);
                                    Debug.print("  free: [" # debug_show free_addr # ", " # debug_show (free_addr + free_size) # ")");
                                    Debug.print("  live: [" # debug_show b.address # ", " # debug_show (b.address + b.size) # ")");
                                    assert false;
                                };
                            };
                        };
                    };
                    switch (FreeMemory.reallocate(fm, 10)) {
                        case (?alloc_addr) {
                            // verify that alloc_addr doesn't overlap any live block
                            // (this is what we're ultimately trying to catch)
                            for (b in blocks.vals()) {
                                if (b.live) {
                                    let overlap = not (alloc_addr + 10 <= b.address or b.address + b.size <= alloc_addr);
                                    if (overlap) {
                                        Debug.print("OVERLAP at iter=" # debug_show iteration);
                                        Debug.print("  allocated: addr=" # debug_show alloc_addr # " size=10");
                                        Debug.print("  live block: addr=" # debug_show b.address # " size=" # debug_show b.size);
                                        assert false;
                                    };
                                };
                            };
                            check(fm, "after realloc iter=" # debug_show iteration);
                        };
                        case (null) {};
                    };
                    check(fm, "after realloc step iter=" # debug_show iteration);

                    // === Step C: Resize a live block (resize => reclaim + realloc) ===
                    switch (pick_live()) {
                        case (?resize_idx) {
                            let b = blocks.get(resize_idx);
                            let new_size_class = fuzz.nat.randomRange(0, 2);
                            let new_size = if (new_size_class == 0) {
                                fuzz.nat.randomRange(3, 15)
                            } else if (new_size_class == 1) {
                                fuzz.nat.randomRange(17, 32)
                            } else {
                                fuzz.nat.randomRange(34, 50)
                            };
                            switch (FreeMemory.reclaim_and_assign_new_size(fm, b.address, b.size, ?new_size)) {
                                case (?new_addr) {
                                    b.live := false; // old address is now free
                                    // The block was resized in-place or returned a new address
                                    // We just need to ensure no overlap with other live blocks
                                    for (other in blocks.vals()) {
                                        if (other.live and other.address != b.address) {
                                            let overlap = not (new_addr + new_size <= other.address or other.address + other.size <= new_addr);
                                            if (overlap) {
                                                Debug.print("RESIZE OVERLAP at iter=" # debug_show iteration);
                                                assert false;
                                            };
                                        };
                                    };
                                    check(fm, "after resize iter=" # debug_show iteration);
                                };
                                case (null) {
                                    b.live := false;
                                };
                            };
                            check(fm, "after resize step iter=" # debug_show iteration);
                        };
                        case (null) {};
                    };

                    iteration += 1;
                };
            },
        );

        // -----------------------------------------------------------------------
        // Minimal reproducer: fill/drain free pool, check max invariant.
        // -----------------------------------------------------------------------
        test(
            "fill and drain via reclaim_and_assign_new_size and reallocate",
            func() {
                let fm = FreeMemory.new();

                // Build adjacent blocks: sizes alternate 5, 50, 5, 50...
                // The large blocks will be the max entries.
                var cursor = 64;
                let count = 200;
                let sizes = Buffer.Buffer<(Nat, Nat)>(count); // (address, size)
                for (i in Iter.range(0, count - 1)) {
                    let size = if (i % 2 == 0) 5 else 50;
                    sizes.add((cursor, size));
                    cursor += size;
                };

                // Deallocate all (they are all adjacent, will merge eagerly)
                for ((addr, size) in sizes.vals()) {
                    ignore FreeMemory.reclaim_and_assign_new_size(fm, addr, size, null);
                    check(fm, "after dealloc " # debug_show (addr, size));
                };

                // Now reallocate 20 bytes at a time from the free pool
                var allocs = Buffer.Buffer<Nat>(50);
                var more = true;
                while (more) {
                    switch (FreeMemory.reallocate(fm, 20)) {
                        case (?addr) {
                            allocs.add(addr);
                            check(fm, "after realloc " # debug_show addr);
                        };
                        case (null) { more := false };
                    };
                };

                // Re-deallocate all allocated blocks
                for (addr in allocs.vals()) {
                    ignore FreeMemory.reclaim_and_assign_new_size(fm, addr, 20, null);
                    check(fm, "after re-dealloc " # debug_show addr);
                };
            },
        );

    },
);
