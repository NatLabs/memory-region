import Region "mo:base/Region";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Prelude "mo:base/Prelude";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";

import MaxBpTree "mo:augmented-btrees/MaxBpTree";

import Utils "Utils";
import FreeMemory "FreeMemory";

module MemoryRegion {

    public type Pointer = (address : Nat, size : Nat);
    type Result<T, E> = Result.Result<T, E>;

    public type FreeMemory = FreeMemory.FreeMemory;

    public type MemoryRegion = {
        region : Region;

        /// The free memory type is a BTree data-structure that stores free memory pointer.
        var free_memory : FreeMemory;

        /// Total number of deallocated bytes.
        var deallocated : Nat;

        /// acts as a bound on the total number of bytes allocated.
        /// includes both allocated and deallocated bytes.
        var size : Nat;

        var pages : Nat;
    };

    public let PageSize : Nat = 65536;

    public func new() : MemoryRegion {
        let allocator : MemoryRegion = {
            region = Region.new();
            var deallocated = 0;
            var size = 0;
            var free_memory = FreeMemory.new();
            var pages = 0;
        };

        allocator;
    };

    public func getFreeMemory(self : MemoryRegion) : [(Nat, Nat)] {
        FreeMemory.toArray(self.free_memory);
    };

    /// Total number of bytes allocated including deallocated bytes.
    public func size(self : MemoryRegion) : Nat {
        Nat64.toNat(Region.size(self.region));
    };

    /// Total number of bytes available before the allocator needs to grow.
    public func capacity(self : MemoryRegion) : Nat {
        MemoryRegion.size(self) * PageSize;
    };

    /// Number of pages allocated. (1 page = 64KB)
    public func pages(self : MemoryRegion) : Nat {
        self.pages;
    };

    /// Total number of bytes allocated and in use.
    public func allocated(self : MemoryRegion) : Nat {
        (self.size - self.deallocated) : Nat;
    };

    /// Total number of bytes deallocated.
    public func deallocated(self : MemoryRegion) : Nat {
        self.deallocated;
    };

    public type MemoryInfo = {
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

    /// Information about the memory usage of the allocator.
    public func memoryInfo(allocator : MemoryRegion) : MemoryInfo {
        let pages = Nat64.toNat(Region.size(allocator.region));
        let capacity = pages * PageSize;

        let size = allocator.size;
        let deallocated = allocator.deallocated;

        let allocated = (allocator.size - deallocated) : Nat;

        let info : MemoryInfo = {
            pages;
            size;
            capacity;
            allocated;
            deallocated;
        };
    };

    public func deallocate(self : MemoryRegion, address : Nat, size : Nat) {

        if (address + size > self.size) {
            Debug.print(debug_show (address, size, self.size));
            return Debug.trap("MemoryRegion.deallocate(): memory block out of bounds");
        };

        FreeMemory.reclaim(self.free_memory, address, size);
        self.deallocated += size; // move to free memory
    };

    public func allocate(self : MemoryRegion, bytes : Nat) : Nat {
        switch (FreeMemory.reallocate(self.free_memory, bytes)) {
            case (?address) {
                self.deallocated -= bytes;
                return address;
            };
            case (null) {};
        };

        growIfNeeded(self, bytes);

        let address = self.size;
        self.size += bytes;

        return address;

    };

    public func grow(self : MemoryRegion, pages : Nat) : Nat {
        let prev_pages = Region.grow(self.region, Nat64.fromNat(pages));
        self.pages += pages;
        Nat64.toNat(prev_pages);
    };

    /// Grows the memory region if needed to allocate the given number of `bytes`.
    public func growIfNeeded(self : MemoryRegion, bytes : Nat) {
        let unused = (capacity(self) - self.size) : Nat;

        if (bytes <= unused) {
            return;
        };

        let overflow = (bytes - unused) : Nat;

        let pages_to_allocate = Utils.div_ceil(overflow, PageSize);
        let prev_pages = Region.grow(self.region, Nat64.fromNat(pages_to_allocate));
        self.pages += pages_to_allocate;
    };

    public func isFreed(self: MemoryRegion, address : Nat, size : Nat) : Result<Bool, Text> {
        FreeMemory.contains(self.free_memory, address, size);
    };

    /// Resets the memory region to its initial state.
    public func clear(self : MemoryRegion) {
        self.free_memory := FreeMemory.new();
        self.deallocated := 0;
        self.size := 0;
    };

    public func storeBlob(self : MemoryRegion, address : Nat, blob : Blob) {
        Region.storeBlob(self.region, Nat64.fromNat(address), blob);
    };

    // public func storeBlobPE(self : MemoryRegion, address : Nat, blob : Blob) : Result<MemoryRegion, String> {
    //     let result = Region.storeBlobPE(self.region, Nat64.fromNat(address), blob);
    //     switch (result) {
    //         case (?region) { return (?{ self with region = region }); };
    //         case (err) { return (err); };
    //     };
    // };

    public func addBlob(self : MemoryRegion, blob : Blob) : Nat {
        let address = allocate(self, blob.size());
        Region.storeBlob(self.region, Nat64.fromNat(address), blob);

        address;
    };

    public func loadBlob(self : MemoryRegion, address : Nat, size : Nat) : Blob {
        Region.loadBlob(self.region, Nat64.fromNat(address), size);
    };

    public func removeBlob(self : MemoryRegion, address : Nat, size : Nat) : Blob {
        let old_blob = Region.loadBlob(self.region, Nat64.fromNat(address), size);
        deallocate(self, address, size);

        old_blob;
    };

};
