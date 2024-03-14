import Debug "mo:base/Debug";

import MaxBpTree "mo:augmented-btrees/MaxBpTree";
import Cmp "mo:augmented-btrees/Cmp";
import BTree "mo:stableheapbtreemap/BTree";
import Set "mo:map/Set";
import Nat "mo:base/Nat";

module {

    type BTree<K, V> = BTree.BTree<K, V>;
    type Set<A> = Set.Set<A>;

    public type VersionedMemoryRegion = {
        #v0 : MemoryRegionV0;
        #v1 : MemoryRegionV1;
    };

    public type CurrentMemoryRegion = MemoryRegionV1;
    
    public func migrate(versions: VersionedMemoryRegion) : VersionedMemoryRegion {
        switch(versions){
            case (#v0(v0)){
                // The size remains the same but all the memory is deallocated.
                let v1 : MemoryRegionV1 = {
                    region = v0.region;
                    var deallocated = v0.size;
                    var size = v0.size;
                    var pages = v0.pages;
                    var free_memory = MaxBpTree.fromEntries([(0, v0.size)].vals(), Cmp.Nat, Cmp.Nat, null);
                };

                #v1(v1)
            };

            case (#v1(_)) versions
        };

    };

    public func getCurrentVersion(versions: VersionedMemoryRegion) : CurrentMemoryRegion {
        switch(versions){
            case (#v1(v1)) return v1;
            case (_)  Debug.trap("Incorrect version: Consider migrating to the latest version.");
        };
    };

    public type FreeMemoryV1 = MaxBpTree.MaxBpTree<Nat, Nat>;

    public type MemoryRegionV1 = {
        region : Region;

        /// The free memory type is a BTree data-structure that stores free memory pointer.
        var free_memory : FreeMemoryV1;

        /// Total number of deallocated bytes.
        var deallocated : Nat;

        /// acts as a bound on the total number of bytes allocated.
        /// includes both allocated and deallocated bytes.
        var size : Nat;

        var pages : Nat;
    };

    public type FreeMemoryV0 = {
        addresses : BTree<Nat, Nat>;
        sizes : BTree<Nat, Set<Nat>>;
    };

    public type MemoryRegionV0 = {
        region : Region;
        var free_memory : FreeMemoryV0;
        var deallocated : Nat;
        var size : Nat;
        var pages : Nat;
    };

};