import Array "mo:base/Array";
import Result "mo:base/Result";
import Prelude "mo:base/Prelude";
import Option "mo:base/Option";
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
            addresses = BTree.init(?32);
            sizes = BTree.init(?32);
        };
    };

    
    func replace_sync(self : FreeMemory, address : Nat, size : Nat) : ?Nat {
        let opt_prev_size = BTree.insert<Nat, Nat>(self.addresses, Nat.compare, address, size);

        replace_size(self, address, opt_prev_size, size);

        return opt_prev_size;
    };  

    func replace_size(self: FreeMemory, address: Nat, opt_prev_size: ?Nat, new_size: Nat){

        let removed_set: ?Set<Nat> = switch(opt_prev_size){
            case (?prev_size){
                let ?set = BTree.get(self.sizes, Nat.compare, prev_size) else Debug.trap("MemoryRegion: size not found in sizes map");
                ignore Set.remove<Nat>(set, nhash, address);
                
                if (Set.size(set) == 0){
                    BTree.delete<Nat, Set<Nat>>(self.sizes, Nat.compare, prev_size);
                }else {
                    null
                }
            };
            case (_){ null; }
        };
        
        let opt_set = BTree.get(self.sizes, Nat.compare, new_size);

        let new_size_set = switch (opt_set) {
            case (?set) set;
            case (null) {
                let set = Option.get(removed_set, Set.new<Nat>());
                ignore BTree.insert(self.sizes, Nat.compare, new_size, set);
                set;
            };
        };

        ignore Set.put<Nat>(new_size_set, nhash, address);

    };

    func delete_sync(self:  FreeMemory, address : Nat) {
        let ?size = BTree.delete(self.addresses, Nat.compare, address) else return;

        let ?set = BTree.get(self.sizes, Nat.compare, size) else Debug.trap("MemoryRegion delete_sync: size not found in sizes map");

        ignore Set.remove<Nat>(set, nhash, address);
        if (Set.size(set) == 0){
            ignore BTree.delete(self.sizes, Nat.compare, size);
        }
    };

    func can_merge_forward(address_a: Nat, size_a: Nat, address_b: Nat, size_b: Nat): Bool {
        address_a + size_a == address_b
    };

    public func reclaim(self : FreeMemory, address : Nat, size : Nat) {
        if (size == 0) return;
        let opt_prev = BTreeUtils.getPrevious(self.addresses, Nat.compare, address);

        let next_address = address + size;
        let opt_next_size = BTree.get(self.addresses, Nat.compare, next_address);

        var address_var = address;
        var size_var = size;
        
        switch (opt_prev, opt_next_size) {
            case (?prev, ?next_size) {

                if (can_merge_forward(prev.0, prev.1, address_var, size_var)){
                    address_var := prev.0;
                    size_var += prev.1;
                };

                if (can_merge_forward(address_var, size_var, next_address, next_size)){
                    size_var += next_size;
                    delete_sync(self, next_address);
                };
            };
            case (?prev, _) {

                if (can_merge_forward(prev.0, prev.1, address_var, size_var)){
                    address_var := prev.0;
                    size_var += prev.1;
                };
            };
            case (_, ?next_size) { 
                if (can_merge_forward(address_var, size_var, next_address, next_size)){
                    size_var += next_size;
                    delete_sync(self, next_address);
                };

            };
            case (_) { };
        };

        ignore replace_sync(self, address_var, size_var);
    };

    public func get_pointer(self : FreeMemory, size_needed : Nat) : ?(address: Nat) {
        let opt_set = BTreeUtils.getCeiling(self.sizes, Nat.compare, size_needed);
        let ?(size, set) = opt_set else return null;

        if (Set.size(set) == 0){
            Debug.print("display: " # debug_show (display(self)) # "\n");
        };
        let ?address = Set.pop(set, nhash) else Debug.trap("MemoryRegion: found empty set in sizes map. [Report this bug to the developers if you see this message]");
            
        assert size >= size_needed;

        // Debug.print("get_pointer: size_needed = " # debug_show (size_needed) # ", ptr = " # debug_show (address, size) # "\n");
        if (size == size_needed) {
            delete_sync(self, address);
            return ?address;
        };

        let split_index = (size - size_needed) : Nat;
        let trimmed_address = address + split_index;

        // update the size of the retrieved pointer in free memory
        ignore replace_sync(self, address, split_index);

        return ?trimmed_address;
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
