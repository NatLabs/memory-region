import Region "mo:base/Region";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Prelude "mo:base/Prelude";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";

import BTree "mo:stableheapbtreemap/BTree";

import BTreeUtils "BTreeUtils";
import Utils "Utils";

module {

    public type Pointer = (Nat, Nat);
    type Result<T, E> = Result.Result<T, E>;
    type BTree<K, V> = BTree.BTree<K, V>;

    public type MemoryRegion = {
        region : Region;

        /// The free memory field consists of a BTree data-structure that stores free memory pointer.
        /// The key is a tuple of the offset index and the size of the memory pointer while the value is left empty.
        free_memory : BTree<(Nat, Nat), ()>;

        /// Total number of deallocated bytes.
        var deallocated : Nat; 

        /// acts as a bound on the total number of bytes allocated.
        /// includes both allocated and deallocated bytes.
        var size : Nat; 
    };

    public let PageSize : Nat = 65536;

    public func new() : MemoryRegion {
        let allocator : MemoryRegion = {
            region = Region.new();
            var deallocated = 0;
            var size = 0;
            free_memory = BTree.init(null)
        };
    };

    public func getFreeMemory(self : MemoryRegion) : [(Nat, Nat)] {
        let iter = Iter.map<((Nat, Nat), ()), (Nat, Nat)>(
            BTree.entries(self.free_memory),
            func ((key, ()): ((Nat, Nat), ())): (Nat, Nat){
                key
            }
        );

        Array.tabulate<(Nat, Nat)>(
            BTree.size(self.free_memory),
            func (_: Nat): (Nat, Nat) {
                let ?n = iter.next() else Prelude.unreachable();
                n
            }
        );
    };

    public type SizeInfo = {
        /// Number of pages allocated. (1 page = 64KB)
        pages : Nat;

        /// Number of bytes allocated including deallocated bytes.
        size : Nat;

        /// Total number of bytes available for allocation from allocated pages.
        capacity : Nat;

        /// Total number of bytes allocated and in use.
        allocated : Nat;

        /// Total number of bytes deallocated.
        deallocated : Nat;
    };

    public func size_info(allocator : MemoryRegion) : SizeInfo {
        let pages = Nat64.toNat(Region.size(allocator.region));
        let capacity = pages * PageSize;

        let size = allocator.size;
        let deallocated = allocator.deallocated;

        let allocated = (allocator.size - deallocated) : Nat;

        let info : SizeInfo = {
            pages;
            size;
            capacity;
            allocated;
            deallocated;
        };
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

    func split(a: Pointer, bytes: Nat) : (allocated: Pointer, rem: ?Pointer) {
        let (offset, size) = a;
        
        if (bytes > size) {
            return Debug.trap("Cannot split pointer: " # debug_show(a) # " " # debug_show(bytes));
        }else if (size == bytes){
            return (a, null);
        };

        let shorted_ptr_size = (size - bytes) : Nat;

        let bytes_ptr = (shorted_ptr_size + offset, bytes);
        let extra_ptr = (offset, shorted_ptr_size);

        (bytes_ptr, ?extra_ptr);
    };

    public func deallocate(allocator : MemoryRegion, ptr : Pointer) : Result<(), Text> {
        let (offset, bytes) = ptr;

        let { size = allocator_size } = size_info(allocator);

        if (offset + bytes > allocator_size) {
            return #err("Pointer out of bounds");
        };

        let btree_offset_cmp = Utils.cmp_first_tuple_item(Nat.compare);

        let opt_prev = BTreeUtils.getPreviousKey(allocator.free_memory, btree_offset_cmp, ptr);
        let opt_next = BTreeUtils.getNextKey(allocator.free_memory, btree_offset_cmp, ptr);

        func merge_prev(curr: Pointer, prev: Pointer): Pointer {
            switch(merge(prev, curr)){
                case (?merged){ merged };
                case (null) { curr };
            };
        };

        func merge_next(curr: Pointer, next: Pointer): Pointer {
            switch(merge(next, curr)){
                case (?merged){
                    let deleted =  BTree.delete(allocator.free_memory, btree_offset_cmp, next);
                    merged
                };
                case (null) { curr };
            };
        };

        let combined = switch (opt_prev, opt_next){
            case (?prev, ?next) {
                let curr = merge_prev(ptr, prev);
                merge_next(curr, next);
            };
            case (?prev, _) { merge_prev(ptr, prev) };
            case (_, ?next){ merge_next(ptr, next) };

            case (_) { ptr} 
        };

        ignore BTree.insert(allocator.free_memory, btree_offset_cmp, combined, ());
        allocator.deallocated += bytes;

        #ok();
    };

    public func allocate(allocator : MemoryRegion, bytes : Nat) : Pointer {
        
        // must use for insertions
        let btree_offset_cmp = Utils.cmp_first_tuple_item(Nat.compare);
        
        // should only be used for lookups
        let btree_size_cmp = Utils.cmp_second_tuple_item(Nat.compare);
        let opt_ceiling_key = BTreeUtils.getCeilingKey(allocator.free_memory, btree_size_cmp, (0, bytes));
        
        switch (opt_ceiling_key){
            case (?ceiling_ptr){

                let (segment, rem) = split(ceiling_ptr, bytes);

                switch(rem) {
                    case(?rem) {
                        // rem and ceiling_ptr should have the same offset.
                        ignore BTree.insert(allocator.free_memory, btree_offset_cmp, rem, ());
                    };
                    case (null) {
                        ignore BTree.delete(allocator.free_memory, btree_offset_cmp, ceiling_ptr)
                    };
                };

                return (segment);
            };
            case (null) {}
        };

        let info = size_info(allocator);

        let unused = (info.capacity - info.size) : Nat;

        if (bytes < unused){
            let offset = Nat64.fromNat(info.size);
            allocator.size += bytes;

            return ((Nat64.toNat(offset), bytes));
        };

        let overflow = (bytes - unused) : Nat;
        
        let pages_to_allocate = Utils.div_ceil(overflow, PageSize);
        let prev_pages = Region.grow(allocator.region, Nat64.fromNat(pages_to_allocate));
        
        let offset = Nat64.fromNat(allocator.size);
        allocator.size += bytes;

        return ((Nat64.toNat(offset), bytes));
       
    };
    
    public func storeBlob(self : MemoryRegion, ptr: Pointer, blob: Blob) : () {
        let (offset, size) = ptr;
        Region.storeBlob(self.region, Nat64.fromNat(offset), blob);
    };

    public func addBlob(self : MemoryRegion, blob: Blob) : Pointer {
        let (offset, size) = allocate(self, blob.size());
        Region.storeBlob(self.region, Nat64.fromNat(offset), blob);

        (offset, size);
    };

    public func replaceBlob(self: MemoryRegion, ptr: Pointer, blob: Blob) : ?Blob {
        assert blob.size() == ptr.1;

        let (offset, size) = ptr;
        let old_blob = Region.loadBlob(self.region, Nat64.fromNat(offset), size);
        Region.storeBlob(self.region, Nat64.fromNat(offset), blob);
        ?old_blob;
    };

    public func loadBlob(self : MemoryRegion, ptr : Pointer) : Blob {
        let (offset, size) = ptr;
        Region.loadBlob(self.region, Nat64.fromNat(offset), size);
    };

    public func removeBlob(self : MemoryRegion, ptr : Pointer) : Blob {
        let (offset, size) = ptr;
        let old_blob = Region.loadBlob(self.region, Nat64.fromNat(offset), size);
        let #ok() = deallocate(self, ptr) else return "";
        old_blob;
    };  

};