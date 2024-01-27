import Array "mo:base/Array";
import Result "mo:base/Result";
import Prelude "mo:base/Prelude";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";

import MaxBpTree "mo:augmented-btrees/MaxBpTree";

module FreeMemory {
    public type Pointer = (address : Nat, size : Nat);
    type Result<T, E> = Result.Result<T, E>;

    public type FreeMemory = MaxBpTree.MaxBpTree<Nat, Nat>;

    public func new() : FreeMemory {
        MaxBpTree.new<Nat, Nat>(?32);
    };

    func can_merge_forward(address_a : Nat, size_a : Nat, address_b : Nat, size_b : Nat) : Bool {
        address_a + size_a == address_b;
    };
    func compare(a : Nat, b : Nat) : Int8 {
        if (a > b) {
            return 1;
        } else if (a < b) {
            return -1;
        } else {
            return 0;
        };
    };

    public func reclaim(self : FreeMemory, address : Nat, size : Nat) {
        if (size == 0) return;

        // retrieves the block with the address just before the one we are trying to reclaim
        let opt_prev = MaxBpTree.getFloor(self, compare, address);

        let next_address = address + size;
        let opt_next_size = MaxBpTree.remove(self, compare, compare, next_address);

        var address_var = address;
        var size_var = size;

        switch (opt_prev) {
            case (?prev) {
                if (can_merge_forward(prev.0, prev.1, address_var, size_var)) {
                    address_var := prev.0;
                    size_var += prev.1;
                };
            };
            case (_) {};
        };

        switch (opt_next_size) {
            case (?next_size) size_var += next_size;
            case (_) {};
        };

        ignore MaxBpTree.insert(self, compare, compare, address_var, size_var);
    };

    public func reallocate(self : FreeMemory, size_needed : Nat) : ?(address : Nat) {
        if (size_needed == 0) return ?0x00; // the library does not store 0 sized blocks, so any address will do as it does not read from it

        let ?(address, size) = MaxBpTree.maxValue(self) else return null;
        if (size < size_needed) return null;

        if (size == size_needed) {
            ignore MaxBpTree.remove(self, compare, compare, address);
            return ?address;
        };

        let split_size = (size - size_needed) : Nat;
        let trimmed_address = address + split_size;

        // update the size of the retrieved pointer in free memory
        ignore MaxBpTree.insert(self, compare, compare, address, split_size);

        return ?trimmed_address;
    };

    // Checks if the given address is properly freed, that is, if is fully contained within a free block
    public func contains(self : FreeMemory, address : Nat, size : Nat) : Result<Bool, Text> {
        let ?recieved = MaxBpTree.getFloor(self, compare, address) else return #ok(false);
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
