import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Option "mo:base/Option";

import Cmp "mo:augmented-btrees/Cmp";
import MaxBpTree "mo:augmented-btrees/MaxBpTree";
import MaxBpTreeMethods "mo:augmented-btrees/MaxBpTree/Methods";
import MaxBpTreeUtils "mo:augmented-btrees/internal/Utils";
import ArrayMut "mo:augmented-btrees/internal/ArrayMut";
import MaxBpTreeBranch "mo:augmented-btrees/MaxBpTree/Branch";
import MaxBpTreeLeaf "mo:augmented-btrees/MaxBpTree/Leaf";
import MaxBpTreeTypes "mo:augmented-btrees/MaxBpTree/Types";
import RevIter "mo:itertools/RevIter";

module FreeMemory {
    type RevIter<A> = RevIter.RevIter<A>;
    public type MemoryBlock = (address : Nat, size : Nat);
    type Result<T, E> = Result.Result<T, E>;

    let { Const = C } = MaxBpTreeTypes;

    public type FreeMemory = MaxBpTree.MaxBpTree<Nat, Nat>;

    public func new() : FreeMemory {
        MaxBpTree.new<Nat, Nat>(?32);
    };

    type BpTreeReference = (
        leaf_node : MaxBpTree.Leaf<Nat, Nat>,
        index : Nat,
        entry : (Nat, Nat),
    );

    type FloorAndCeilingReferences = (
        floor : ?BpTreeReference,
        ceil : ?BpTreeReference,
    );

    // !performs slower than the code in reclaim_and_assign_new_size because of the transformation, extra checks and returning tuple collections
    public func get_floor_and_ceiling_references(self : FreeMemory, address : Nat, size : Nat) : FloorAndCeilingReferences {

        // get floor
        var leaf_node = MaxBpTreeMethods.get_leaf_node(self, Cmp.Nat, address);
        let int_index = ArrayMut.binary_search(leaf_node.3, MaxBpTreeUtils.adapt_cmp(Cmp.Nat), address, leaf_node.0 [C.COUNT]);

        if (int_index >= 0) {
            Debug.print("address should not exist in the tree");
            Debug.print("intersection between (address, size): " # debug_show (address, size));
            Debug.print("This might be because you are trying to free a block or part of a block was already freed");
            Debug.trap("If you are sure this is not the case, please report this bug to the library's maintainer on github");
        };

        var expected_index = Int.abs(int_index) - 2 : Int; // the pos of the floor

        let opt_floor = if (expected_index == -1) {
            switch (leaf_node.2 [C.PREV]) {
                case (?prev_node) {
                    leaf_node := prev_node;
                    expected_index := (prev_node.0 [C.COUNT] - 1 : Nat);
                    prev_node.3 [Int.abs(expected_index)];
                };
                case (_) {
                    null;
                };
            };
        } else if (expected_index < leaf_node.0 [C.COUNT]) {
            leaf_node.3 [Int.abs(expected_index)];
        } else {
            null;
        };

        var ceiling_index : Int = 0;
        let opt_next = if (expected_index + 1 < leaf_node.0 [C.COUNT]) {
            ceiling_index := expected_index + 1;
            leaf_node.3 [Int.abs(expected_index + 1)];
        } else {
            switch (leaf_node.2 [C.NEXT]) {
                case (?next) next.3 [0];
                case (_) null;
            };
        };

        switch (opt_floor, opt_next) {
            case (null, null) (null, null);
            case (?floor, null) {
                (?(leaf_node, Int.abs(expected_index), floor), null);
            };
            case (null, ?next) {
                (null, ?(leaf_node, Int.abs(ceiling_index), next));
            };
            case (?floor, ?next) {
                (
                    ?(leaf_node, Int.abs(expected_index), floor),
                    ?(
                        leaf_node,
                        Int.abs(ceiling_index),
                        next,
                    ),
                );
            };
        };

    };

    public func reclaim_and_assign_new_size(self : FreeMemory, address : Nat, curr_size : Nat, opt_new_size : ?Nat) : ?Nat {
        if (curr_size == 0) return null;

        switch (opt_new_size) {
            // return the address if the new size is the same as the current size
            case (?new_size) if (new_size == curr_size) return ?address;
            case (_) {};
        };

        // get floor
        var leaf_node = MaxBpTreeMethods.get_leaf_node(self, Cmp.Nat, address);
        let int_index = ArrayMut.binary_search(leaf_node.3, MaxBpTreeUtils.adapt_cmp(Cmp.Nat), address, leaf_node.0 [C.COUNT]);

        if (int_index >= 0) {
            Debug.print("address should not exist in the tree");
            Debug.print("intersection between (address, size): " # debug_show (address, curr_size));
            Debug.print("This might be because you are trying to free a block or part of a block was already freed");
            Debug.trap("If you are sure this is not the case, please report this bug to the library's maintainer on github");
        };

        // Debug.print("Leaf Node: " # debug_show MaxBpTreeLeaf.toText(leaf_node, Nat.toText, Nat.toText));

        // Debug.print("int_index: " # debug_show int_index);

        var expected_index = Int.abs(int_index) - 2 : Int; // the pos of the floor

        let opt_floor = if (expected_index == -1) {
            switch (leaf_node.2 [C.PREV]) {
                case (?prev_node) {
                    leaf_node := prev_node;
                    expected_index := (prev_node.0 [C.COUNT] - 1 : Nat);
                    prev_node.3 [Int.abs(expected_index)];
                };
                case (_) {
                    null;
                };
            };
        } else if (expected_index < leaf_node.0 [C.COUNT]) {
            leaf_node.3 [Int.abs(expected_index)];
        } else {
            null;
        };

        var ceiling_index : Int = 0;
        let opt_next = if (expected_index + 1 < leaf_node.0 [C.COUNT]) {
            ceiling_index := expected_index + 1;
            leaf_node.3 [Int.abs(expected_index + 1)];
        } else {
            switch (leaf_node.2 [C.NEXT]) {
                case (?next) next.3 [0];
                case (_) null;
            };
        };

        // Debug.print("opt_floor: " # debug_show opt_floor # ", actual: " # debug_show (MaxBpTree.getFloor(self, Cmp.Nat, address)));
        // Debug.print("opt_next: " # debug_show opt_next # ", actual: " # debug_show (MaxBpTree.getCeiling(self, Cmp.Nat, address + curr_size)));

        // Debug.print("left index: " # debug_show expected_index);
        // Debug.print("right index: " # debug_show (ceiling_index));

        var memory_block_address = address;
        var memory_block_size = curr_size;

        // Debug.print("address: " # debug_show address # ", curr_size: " # debug_show curr_size);

        // assert opt_floor == MaxBpTree.getFloor(self, Cmp.Nat, address);
        // assert opt_next == MaxBpTree.getCeiling(self, Cmp.Nat, address + curr_size);

        // reclaim the memory block and merge it with adjacent free memory blocks if possible
        switch (opt_floor, opt_next) {
            case (null, null) {
                ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, address, curr_size);
            };
            case (?floor, null) {
                // floor memory block aligns with the address of the block we are trying to reclaim
                if (floor.0 + floor.1 == address) {
                    ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, floor.0, floor.1 + curr_size);
                    memory_block_address := floor.0;
                    memory_block_size := floor.1 + curr_size;
                } else {
                    ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, address, curr_size);
                };
            };
            case (null, ?next) {
                // next memory block aligns with the address of the block we are trying to reclaim
                if (next.0 == address + curr_size) {
                    ignore MaxBpTree.remove(self, Cmp.Nat, Cmp.Nat, next.0);
                    ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, address, curr_size + next.1);
                    memory_block_address := address;
                    memory_block_size := curr_size + next.1;
                } else {
                    ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, address, curr_size);
                };
            };
            case (?floor, ?next) {
                if (floor.0 + floor.1 == address and address + curr_size == next.0) {
                    ignore MaxBpTree.remove(self, Cmp.Nat, Cmp.Nat, next.0);
                    ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, floor.0, floor.1 + curr_size + next.1);
                    memory_block_address := floor.0;
                    memory_block_size := floor.1 + curr_size + next.1;
                } else if (floor.0 + floor.1 == address) {
                    ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, floor.0, floor.1 + curr_size);
                    memory_block_address := floor.0;
                    memory_block_size := floor.1 + curr_size;
                } else if (next.0 == address + curr_size) {
                    ignore MaxBpTree.remove(self, Cmp.Nat, Cmp.Nat, next.0);
                    ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, address, curr_size + next.1);
                    memory_block_size := curr_size + next.1;
                } else {
                    ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, address, curr_size);
                };
            };
        };

        // Debug.print("memory_block_address: " # debug_show memory_block_address # ", memory_block_size: " # debug_show memory_block_size);

        if (opt_new_size == null or opt_new_size == ?0) { return null };

        // allocate the requested memory block size
        let new_size = Option.get(opt_new_size, 0);
        assert new_size != 0;

        if (new_size < memory_block_size) {
            let reclaimed_size = memory_block_size - new_size : Nat;
            ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, memory_block_address, reclaimed_size);
            return ?(memory_block_address + reclaimed_size);
        } else if (new_size == memory_block_size) {
            ignore MaxBpTree.remove(self, Cmp.Nat, Cmp.Nat, memory_block_address);
            return ?memory_block_address;
        };

        return null;

    };

    // Reclaims the memory block at the given address and merges it to adjacent free memory blocks if possible.
    //
    // If the memory block is resized, when opt_size_needed is included, it returns the address for the resized block.
    // If the opt_size_needed greater than the size of the block, it returns null.
    //
    // !broken - _insert_at_leaf_index, _replace_at_leaf_index,  _remove_from_leaf, or all 3 are not working properly.
    // todo: fix these functions in the augmented-btrees library.
    public func reclaim_and_assign_new_size_fast(self : FreeMemory, address : Nat, size : Nat, opt_size_needed : ?Nat) : ?Nat {
        if (size == 0) return null;

        switch (opt_size_needed) {
            case (?size_needed) if (size_needed == size) return ?address;
            case (_) {};
        };

        // get floor
        var leaf_node = MaxBpTreeMethods.get_leaf_node(self, Cmp.Nat, address);
        let int_index = ArrayMut.binary_search(leaf_node.3, MaxBpTreeUtils.adapt_cmp(Cmp.Nat), address, leaf_node.0 [C.COUNT]);

        if (int_index >= 0) {
            Debug.print("address should not exist in the tree");
            Debug.print("intersection between (address, size): " # debug_show (address, size));
            Debug.print("This might be because you are trying to free a block or part of a block was already freed");
            Debug.trap("If you are sure this is not the case, please report this bug to the library's maintainer on github");
        };

        let expected_index = Int.abs(int_index) - 1 : Nat; // the pos of the floor
        var int_prev_index : Int = 0;

        let prev_index = do {

            if (expected_index == 0) {
                switch (leaf_node.2 [C.PREV]) {
                    case (?prev_node) {
                        leaf_node := prev_node;
                        (prev_node.0 [C.COUNT] - 1 : Nat);
                    };
                    case (_) {
                        int_prev_index := -1;
                        0;
                    };
                };
            } else {
                (expected_index - 1 : Nat);
            };
        };

        if (int_prev_index != -1) {
            int_prev_index := prev_index;
        };

        var has_prev = false;
        if (prev_index >= 0) {
            switch (leaf_node.3 [prev_index]) {
                case (?(prev_address, prev_size)) {
                    has_prev := (prev_address + prev_size == address);
                };
                case (_) {};
            };
        };

        var next_node = leaf_node;
        let next_index : Nat = if (prev_index + 1 < leaf_node.0 [C.COUNT]) {
            prev_index + 1 : Nat;
        } else {
            switch (leaf_node.2 [C.NEXT]) {
                case (?next) {
                    next_node := next;
                };
                case (_) {};
            };

            0;
        };

        let has_next = switch (next_node.3 [next_index]) {
            case (?(next_address, _)) address + size == next_address;
            case (_) false;
        };

        // Debug.print("(has_prev, has_next): " # debug_show (has_prev, has_next));

        switch (has_prev, has_next) {
            case (false, false) {
                switch (opt_size_needed) {
                    case (?size_needed) {
                        if (size_needed < size) {
                            let reclaimed_size = size - size_needed : Nat;
                            MaxBpTree._insert_at_leaf_index(self, Cmp.Nat, Cmp.Nat, leaf_node, Int.abs(int_prev_index + 1), address, reclaimed_size);

                            let resized_address = address + reclaimed_size;
                            return ?resized_address;
                        };
                    };
                    case (_) {};
                };

                // if size_needed is null or greater than size, insert and return null
                MaxBpTree._insert_at_leaf_index(self, Cmp.Nat, Cmp.Nat, leaf_node, Int.abs(int_prev_index + 1), address, size);
            };
            case (true, false) {
                let ?(prev_address, prev_size) = leaf_node.3 [prev_index] else Debug.trap("prev_index should exist");

                let merged_size = size + prev_size;

                switch (opt_size_needed) {
                    case (?size_needed) if (size_needed < merged_size) {
                        let reclaimed_size = merged_size - size_needed : Nat;
                        ignore MaxBpTree._replace_at_leaf_index(self, Cmp.Nat, Cmp.Nat, leaf_node, prev_index, prev_address, reclaimed_size);

                        let resized_address = prev_address + reclaimed_size;
                        return ?resized_address;
                    } else if (size_needed == merged_size) {
                        ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, leaf_node, prev_index);
                        return ?prev_address;
                    };
                    case (null) {};
                };

                ignore MaxBpTree._replace_at_leaf_index(self, Cmp.Nat, Cmp.Nat, leaf_node, prev_index, prev_address, merged_size);
            };
            case (false, true) {
                let ?(next_address, next_size) = next_node.3 [next_index] else Debug.trap("next_index should exist");
                let merged_size = size + next_size;

                switch (opt_size_needed) {
                    case (?size_needed) if (size_needed < merged_size) {
                        let reclaimed_size = merged_size - size_needed : Nat;
                        ignore MaxBpTree._replace_at_leaf_index(self, Cmp.Nat, Cmp.Nat, next_node, next_index, address, reclaimed_size);
                        if (next_index == 0) {
                            switch (next_node.1 [C.PARENT]) {
                                case (?parent) {
                                    MaxBpTreeBranch.update_median_key<Nat, Nat>(parent, next_node.0 [C.INDEX], address);
                                };
                                case (_) {};
                            };
                        };
                        let resized_address = address + reclaimed_size;

                        assert ?reclaimed_size == MaxBpTree.get(self, Cmp.Nat, address);

                        return ?resized_address;
                    } else if (size_needed == merged_size) {
                        // Debug.print("merged_size: " # debug_show merged_size);
                        // Debug.print("should remove next " # debug_show (next_address, next_size));
                        ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, next_node, next_index);
                        return ?address;
                    };
                    case (null) {};
                };

                ignore MaxBpTree._replace_at_leaf_index(self, Cmp.Nat, Cmp.Nat, next_node, next_index, address, merged_size);

                if (next_index == 0) {
                    switch (next_node.1 [C.PARENT]) {
                        case (?parent) {
                            MaxBpTreeBranch.update_median_key<Nat, Nat>(parent, next_node.0 [C.INDEX], address);
                        };
                        case (_) {};
                    };
                };
            };
            case (true, true) {
                let ?(prev_address, prev_size) = leaf_node.3 [prev_index] else Debug.trap("prev_index should exist");
                let ?(next_address, next_size) = next_node.3 [next_index] else Debug.trap("next_index should exist");
                let merged_size = size + prev_size + next_size;

                // Debug.print("size needed: " # debug_show opt_size_needed);
                // Debug.print("merged size: " # debug_show merged_size);

                // Debug.print("Leaf Node: " # debug_show MaxBpTreeLeaf.toText(leaf_node, Nat.toText, Nat.toText));
                // Debug.print("Next Node: " # debug_show MaxBpTreeLeaf.toText(next_node, Nat.toText, Nat.toText));

                switch (opt_size_needed) {
                    case (?size_needed) if (size_needed < merged_size) {
                        let reclaimed_size = merged_size - size_needed : Nat;
                        ignore MaxBpTree._replace_at_leaf_index(self, Cmp.Nat, Cmp.Nat, leaf_node, prev_index, prev_address, reclaimed_size);
                        ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, next_node, next_index);
                        let resized_address = prev_address + reclaimed_size;
                        return ?resized_address;
                    } else if (size_needed == merged_size) {
                        // ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, next_node, next_index);
                        // ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, leaf_node, prev_index);

                        if (leaf_node.0 [C.ID] == next_node.0 [C.ID]) {
                            assert prev_index + 1 == next_index;
                            Debug.print("Leaf node count: " # debug_show leaf_node.0 [C.COUNT]);
                            Debug.print("removing two nodes from the same leaf");
                            Debug.print("left index " # debug_show prev_index);
                            Debug.print("right index " # debug_show next_index);

                            Debug.print("Leaf Node: " # debug_show MaxBpTreeLeaf.toText(leaf_node, Nat.toText, Nat.toText));

                            ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, next_node, next_index - 1);
                            Debug.print("Leaf Node after right node is removed: " # debug_show MaxBpTreeLeaf.toText(leaf_node, Nat.toText, Nat.toText));

                            ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, leaf_node, prev_index);
                            Debug.print("Leaf Node after left node is removed: " # debug_show MaxBpTreeLeaf.toText(leaf_node, Nat.toText, Nat.toText));
                            // after removing the previous node, the index of the next node is shifted by one
                            // so we need to adjust the next_index to point to the same node

                            // ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, next_node, next_index);
                            // ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, leaf_node, prev_index);

                        } else {

                            ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, next_node, next_index);
                            ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, leaf_node, prev_index);
                        };

                        return ?prev_address;
                    };
                    case (null) {};
                };

                ignore MaxBpTree._replace_at_leaf_index(self, Cmp.Nat, Cmp.Nat, leaf_node, prev_index, prev_address, merged_size);
                // Debug.print("after replace");
                // Debug.print("Leaf Node: " # debug_show MaxBpTreeLeaf.toText(leaf_node, Nat.toText, Nat.toText));
                // Debug.print("Next Node: " # debug_show MaxBpTreeLeaf.toText(next_node, Nat.toText, Nat.toText));

                ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, next_node, next_index);

                // Debug.print("after remove");
                // Debug.print("Leaf Node: " # debug_show MaxBpTreeLeaf.toText(leaf_node, Nat.toText, Nat.toTex

            };
        };

        null;
    };

    public func reallocate(self : FreeMemory, size_needed : Nat) : ?(address : Nat) {
        if (size_needed == 0) return null;

        let max_block = switch (MaxBpTree.maxValue(self)) {
            case (null) return null;
            case (?max) max;
        };

        let address = max_block.0;
        let size = max_block.1;

        if (size < size_needed) return null;

        if (size == size_needed) {
            // Debug.print("reallocate: removing block of size " # debug_show size);
            // Debug.print(debug_show toArray(self));
            ignore MaxBpTree.remove(self, Cmp.Nat, Cmp.Nat, address);
            return ?address;
        };

        let split_size = (size - size_needed) : Nat;

        // Debug.print("reallocate: splitting block of size " # debug_show size # " into " # debug_show (size_needed, split_size));
        // update the size of the retrieved pointer in free memory
        let ?max = MaxBpTree.replaceMaxValue(self, Cmp.Nat, Cmp.Nat, split_size) else Debug.trap("max block should exist");

        let trimmed_address = max.0 + split_size;

        return ?trimmed_address;
    };

    public func deallocated_blocks_in_range(self : FreeMemory, start : Nat, end : Nat) : RevIter<(Nat, Nat)> {
        MaxBpTree.scan<Nat, Nat>(self, Cmp.Nat, start, (end - 1));
    };

    // Checks if the given address is properly freed, that is, if is fully contained within a free block
    public func contains(self : FreeMemory, address : Nat, size : Nat) : Result<Bool, Text> {
        let ?received = MaxBpTree.getFloor(self, Cmp.Nat, address) else return #ok(false);
        let exists = (received.0 + received.1) > address;

        if (exists) {
            if ((received.0 + received.1) < (address + size)) {
                return #err("improperly freed memory: " # debug_show (address, size) # " extends beyond the end of the block " # debug_show received);
            };

            return #ok(true);
        };

        #ok(false);
    };

    /// returns true if the address is found in any of the deallocated blocks range
    public func is_block_deallocated(self : FreeMemory, address : Nat) : Bool {
        let ?block_range = MaxBpTree.getFloor(self, Cmp.Nat, address) else return false;

        let (start, length) = block_range;

        let end = start + length;

        return start <= address and end > address;

    };

    public func total_size(self : FreeMemory) : Nat {
        var total_size = 0 : Nat;
        for (size in MaxBpTree.vals(self)) {
            total_size += size;
        };
        return total_size;
    };

    public func toArray(self : FreeMemory) : [(Nat, Nat)] {
        MaxBpTree.toArray(self);
    };
};
