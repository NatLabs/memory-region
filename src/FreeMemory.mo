import Array "mo:base/Array";
import Result "mo:base/Result";
import Prelude "mo:base/Prelude";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";

import Set "mo:map/Set";
import BTree "mo:stableheapbtreemap/BTree";

import BTreeUtils "BTreeUtils";

module FreeMemory {
    public type Pointer = (address : Nat, size : Nat);
    type Result<T, E> = Result.Result<T, E>;
    type BTree<K, V> = BTree.BTree<K, V>;
    type Set<T> = Set.Set<T>;

    let { nhash } = Set;

    public type FreeMemory = {
        addresses : BTree<Nat, Nat>;
        sizes : BTree<Nat, Set<Nat>>;
    };

    public func new() : FreeMemory {
        {
            addresses = BTree.init(null);
            sizes = BTree.init(null);
        };
    };

    func remove_sync(self : FreeMemory, address : Nat){
        let opt_size = BTree.delete(self.addresses, Nat.compare, address);

        let size = switch (opt_size) {
            case (?size) size;
            case (null) return;
        };

        let opt_set = BTree.get(self.sizes, Nat.compare, size);

        let set = switch (opt_set) {
            case (?set) { set };
            case (null) Debug.trap("MemoryRegion: size not found in sizes map");
        };

        ignore Set.remove<Nat>(set, nhash, address);
    };

    func replace_sync(self : FreeMemory, address : Nat, size : Nat) : ?Nat {
        let opt_prev_size = BTree.insert<Nat, Nat>(self.addresses, Nat.compare, address, size);

        switch(opt_prev_size){
            case (?prev_size){
                let ?set = BTree.get(self.sizes, Nat.compare, prev_size) else Debug.trap("MemoryRegion: size not found in sizes map");
                ignore Set.remove<Nat>(set, nhash, address);
            };
            case (_){};
        };

        let opt_set = BTree.get(self.sizes, Nat.compare, size);
    
        let set = switch (opt_set) {
            case (?set) set;
            case (null) {
                let set : Set<Nat> = Set.new();
                ignore BTree.insert(self.sizes, Nat.compare, size, set);
                set;
            };
        };

        ignore Set.put<Nat>(set, nhash, address);

        return opt_prev_size;
    };

    func delete_sync(self:  FreeMemory, address : Nat) {
        let ?size = BTree.delete(self.addresses, Nat.compare, address) else return;

        let ?set = BTree.get(self.sizes, Nat.compare, size) else Debug.trap("MemoryRegion delete_sync: size not found in sizes map");

        ignore Set.remove<Nat>(set, nhash, address);
    };

    func merge(a: Pointer, b: Pointer): ?Pointer {
        let (offset_a, size_a) = a;
        let (offset_b, size_b) = b;

        if (offset_a + size_a == offset_b){
            ?(offset_a, size_a + size_b)
        }else if (offset_b + size_b == offset_a){
            ?(offset_b, size_a + size_b);
        }else{
            null
        };
    };

    public func reclaim(self : FreeMemory, address : Nat, size : Nat) {
        if (size == 0) return;
        
        let opt_prev = BTreeUtils.getPrevious(self.addresses, Nat.compare, address);
        let opt_next = BTreeUtils.getNext(self.addresses, Nat.compare, address);

        func merge_prev(curr : Pointer, prev : Pointer) : Pointer {
            switch (merge(prev, curr)) {
                case (?merged) { merged };
                case (null) { curr };
            };
        };

        func merge_next(curr : Pointer, next : Pointer) : Pointer {
            switch (merge(next, curr)) {
                case (?merged) {
                    delete_sync(self, next.0);
                    merged;
                };
                case (null) { curr };
            };
        };

        let ptr = (address, size);

        let combined = switch (opt_prev, opt_next) {
            case (?prev, ?next) {
                let curr = merge_prev(ptr, prev);
                merge_next(curr, next);
            };
            case (?prev, _) { merge_prev(ptr, prev) };
            case (_, ?next) { merge_next(ptr, next) };

            case (_) { ptr };
        };

        ignore replace_sync(self, combined.0, combined.1);
    };


    public func get_pointer(self : FreeMemory, size_needed : Nat) : ?(address: Nat) {
        let opt_ceiling = BTreeUtils.getCeiling(self.addresses, Nat.compare, size_needed);

        switch (opt_ceiling) {
            case (null) { null };
            case (?(address, size)) {
                
                if (size_needed > size){
                    return null;
                };

                // Debug.print("get_pointer: size_needed = " # debug_show (size_needed) # ", ptr = " # debug_show (address, size) # "\n");
                if (size == size_needed) {
                    remove_sync(self, address);
                    return ?address;
                };

                let split_point = (size - size_needed) : Nat;
                let trimmed_address = address + split_point;

                // update the size of the retrieved pointer in free memory
                ignore replace_sync(self, address, split_point);

                return ?trimmed_address;
            };
        };
    };

    public func display(self: FreeMemory): {
        sizes: [(Nat, [Nat])];
        addresses: [(Nat, Nat)]
    }{
        {
            addresses = addresses(self);
            sizes = sizes(self);
        }
    };

    public func toArray(self: FreeMemory): [(Nat, Nat)] {
        addresses(self);
    };

    public func addresses(self: FreeMemory): [(Nat, Nat)] {
        let iter = BTree.entries(self.addresses);

        Array.tabulate<(Nat, Nat)>(
            BTree.size(self.addresses),
            func(_ : Nat) : (Nat, Nat) {
                let ?n = iter.next() else Prelude.unreachable();
                n;
            },
        );
    };

    public func sizes(self: FreeMemory) : [(Nat, [Nat])] {
        let iter = BTree.entries(self.sizes);

        Array.tabulate<(Nat, [Nat])>(
            BTree.size(self.sizes),
            func(_ : Nat) : (Nat, [Nat]) {
                let ?entry = iter.next() else Prelude.unreachable();
                (entry.0, Set.toArray(entry.1));
            },
        );
    };
};
