import Array "mo:base/Array";
import Result "mo:base/Result";
import Prelude "mo:base/Prelude";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Debug "mo:base/Debug";

import Cmp "mo:augmented-btrees/Cmp";
import MaxBpTree "mo:augmented-btrees/MaxBpTree";
import MaxBpTreeMethods "mo:augmented-btrees/MaxBpTree/Methods";
import MaxBpTreeUtils "mo:augmented-btrees/internal/Utils";
import ArrayMut "mo:augmented-btrees/internal/ArrayMut";
import MaxBpTreeBranch "mo:augmented-btrees/MaxBpTree/Branch";
import MaxBpTreeLeaf "mo:augmented-btrees/MaxBpTree/Leaf";
import MaxBpTreeTypes "mo:augmented-btrees/MaxBpTree/Types";

module FreeMemory {
    public type Pointer = (address : Nat, size : Nat);
    type Result<T, E> = Result.Result<T, E>;

    let { Const = C } = MaxBpTreeTypes;

    public type FreeMemory = MaxBpTree.MaxBpTree<Nat, Nat>;

    public func new() : FreeMemory {
        MaxBpTree.new<Nat, Nat>(?32);
    };

    func can_merge_forward(address_a : Nat, size_a : Nat, address_b : Nat, size_b : Nat) : Bool {
        address_a + size_a == address_b;
    };
  

    public func reclaim(self : FreeMemory, address : Nat, size : Nat) {
        if (size == 0) return;

        // get floor
        var leaf_node = MaxBpTreeMethods.get_leaf_node(self, Cmp.Nat, address);
        let int_index = ArrayMut.binary_search(leaf_node.3, MaxBpTreeUtils.adapt_cmp(Cmp.Nat), address, leaf_node.0[C.COUNT]);

        let expected_index = Int.abs(int_index) - 1 : Nat; // the pos of the floor

        let prev_index = if (int_index >= 0) Debug.trap("address should not exist in the tree") else {

            if (expected_index == 0) {
                switch (leaf_node.2[C.PREV]) {
                    case (?prev_node) {
                        leaf_node := prev_node;
                        (prev_node.0[C.COUNT] - 1 : Nat);
                    };
                    case (_) (0);
                };
            } else {
                (expected_index - 1 : Nat);
            };
        };

        let has_prev = switch (leaf_node.3[prev_index]) {
            case (?(prev_address, prev_size)) prev_address + prev_size == address;
            case (_) false;
        };
 
        var next_node = leaf_node;
        let next_index : Nat = if (expected_index < leaf_node.0[C.COUNT]) {
            expected_index;
        } else {
            switch (leaf_node.2[C.NEXT]) {
                case (?next) {
                    next_node := next;
                };
                case (_) {};
            };

            0;
        };

        let has_next = switch (next_node.3[next_index]) {
            case (?(next_address, _)) address + size == next_address;
            case (_) false;
        };

        switch (has_prev, has_next) {
            case (false, false) {
                ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, address, size);
            };
            case (true, false) {
                let ?(prev_address, prev_size) = leaf_node.3[prev_index] else Debug.trap("prev_index should exist");
                ignore MaxBpTree._replace_at_leaf_index(self, Cmp.Nat, Cmp.Nat, leaf_node, prev_index, prev_address, size + prev_size, true);
            };
            case (false, true) {
                let ?(next_address, next_size) = next_node.3[next_index] else Debug.trap("next_index should exist");
                ignore MaxBpTree._replace_at_leaf_index(self, Cmp.Nat, Cmp.Nat, next_node, next_index, address, size + next_size, true);

                if (next_index == 0) {
                    switch (next_node.1[C.PARENT]) {
                        case (?parent) {
                            MaxBpTreeBranch.update_median_key<Nat, Nat>(parent, next_node.0[C.INDEX], address);
                        };
                        case (_) {};
                    };
                };
            };
            case (true, true) {
                let ?(prev_address, prev_size) = leaf_node.3[prev_index] else Debug.trap("prev_index should exist");
                let ?(next_address, next_size) = next_node.3[next_index] else Debug.trap("next_index should exist");
                
                // Debug.print("(prev_index, next_index): " # debug_show (prev_index, next_index));

                // Debug.print("Leaf Node: " # debug_show MaxBpTreeLeaf.toText(leaf_node, Nat.toText, Nat.toText));
                // Debug.print("Next Node: " # debug_show MaxBpTreeLeaf.toText(next_node, Nat.toText, Nat.toText));

                ignore MaxBpTree._replace_at_leaf_index(self, Cmp.Nat, Cmp.Nat, leaf_node, prev_index, prev_address, prev_size + size + next_size, true);
                // Debug.print("after replace");
                // Debug.print("Leaf Node: " # debug_show MaxBpTreeLeaf.toText(leaf_node, Nat.toText, Nat.toText));        
                // Debug.print("Next Node: " # debug_show MaxBpTreeLeaf.toText(next_node, Nat.toText, Nat.toText));

                ignore MaxBpTree._remove_from_leaf(self, Cmp.Nat, Cmp.Nat, next_node, next_index, true);

                // Debug.print("after remove");
                // Debug.print("Leaf Node: " # debug_show MaxBpTreeLeaf.toText(leaf_node, Nat.toText, Nat.toText));        
                // Debug.print("Next Node: " # debug_show MaxBpTreeLeaf.toText(next_node, Nat.toText, Nat.toText));
                
            };
        };
    };

    public func reallocate(self : FreeMemory, size_needed : Nat) : ?(address : Nat) {
        if (size_needed == 0) return ?0x00; // the library does not store 0 sized blocks, so any address will do as it does not read from it

        let ?(address, size) = MaxBpTree.maxValue(self) else return null;
        if (size < size_needed) return null;

        if (size == size_needed) {
            ignore MaxBpTree.remove(self, Cmp.Nat, Cmp.Nat, address);
            return ?address;
        };

        let split_size = (size - size_needed) : Nat;
        let trimmed_address = address + split_size;

        // update the size of the retrieved pointer in free memory
        ignore MaxBpTree.insert(self, Cmp.Nat, Cmp.Nat, address, split_size);

        return ?trimmed_address;
    };

    // Checks if the given address is properly freed, that is, if is fully contained within a free block
    public func contains(self : FreeMemory, address : Nat, size : Nat) : Result<Bool, Text> {
        let ?recieved = MaxBpTree.getFloor(self, Cmp.Nat, address) else return #ok(false);
        let exists = recieved.0 <= address and (recieved.0 + recieved.1) >= (address + size);

        if (exists) return #ok(true);
        #err("improperly freed memory");
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
