import Region "mo:base/Region";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Int8 "mo:base/Int8";
import Int16 "mo:base/Int16";
import Int32 "mo:base/Int32";
import Int64 "mo:base/Int64";

import MaxBpTree "mo:augmented-btrees/MaxBpTree";
import Cmp "mo:augmented-btrees/Cmp";

import Utils "Utils";
import FreeMemory "FreeMemory";
import Migrations "Migrations";

module MemoryRegion {

    public type Pointer = (address : Nat, size : Nat);
    type Result<T, E> = Result.Result<T, E>;

    public type FreeMemory = FreeMemory.FreeMemory;

    public type MemoryRegion = Migrations.CurrentMemoryRegion;
    public type VersionedMemoryRegion = Migrations.VersionedMemoryRegion;

    public type MemoryRegionV0 = Migrations.MemoryRegionV0;
    public type MemoryRegionV1 = Migrations.MemoryRegionV1;

    public type MemoryInfo = {
        /// Number of pages allocated. (1 page = 64KB)
        pages : Nat;

        /// Size of the Memory Region in bytes including allocated and deallocated bytes.
        size : Nat;

        /// Total number of bytes available for allocation from allocated pages.
        capacity : Nat;

        /// Total number of bytes allocated and in use.
        allocated : Nat;

        /// Total number of bytes deallocated.
        deallocated : Nat;
    };
    
    public let PageSize : Nat = 65536;

    public func new() : MemoryRegion {
        let self = {
            var deallocated = 0;
            var size = 0;
            var pages = 0;
            region = Region.new();
            var free_memory = FreeMemory.new();
        };

        self;
    };

    /// Create MemoryRegion from shared internal data
    public func fromVersioned(prev_version: VersionedMemoryRegion): MemoryRegion {
        let migrated = Migrations.upgrade(prev_version);
        Migrations.getCurrentVersion(migrated);
    };

    /// Return the simplest state of the MemoryRegion's data so that it only contains 
    /// primitives and can be recreated by any other version
    public func toVersioned(self: MemoryRegion) : VersionedMemoryRegion  {
        #v1(self);
    };

    public func getFreeMemory(self : MemoryRegion) : [(Nat, Nat)] {
        FreeMemory.toArray(self.free_memory);
    };

    /// Total number of bytes allocated including deallocated bytes.
    public func size(self : MemoryRegion) : Nat {
        self.size;
    };

    /// Returns the id of the Region.
    public func id(self: MemoryRegion) : Nat {
        Region.id(self.region);
    };

    /// Total number of bytes available before the allocator needs to grow.
    public func capacity(self : MemoryRegion) : Nat {
        self.pages * PageSize;
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

    /// Information about the memory usage of the region.
    public func memoryInfo(self : MemoryRegion) : MemoryInfo {
        let pages = Nat64.toNat(Region.size(self.region));
        let capacity = pages * PageSize;

        let size = self.size;
        let deallocated = self.deallocated;

        let allocated = (self.size - deallocated) : Nat;

        return {
            pages;
            size;
            capacity;
            allocated;
            deallocated;
        } : MemoryInfo;
    };

    public func deallocate(self : MemoryRegion, address : Nat, size : Nat) {

        if (address + size > self.size) {
            Debug.print(debug_show (address, size, self.size));
            return Debug.trap("MemoryRegion.deallocate(): memory block out of bounds");
        };

        assert null == FreeMemory.reclaim(self.free_memory, address, size, null);
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

    /// Tries to resize a memory block. 
    /// If it is not possible it deallocates the block and allocates a new one.
    /// As a result it is be best to assume that the address of the memory block will change after a resize.
    public func resize(self: MemoryRegion, address: Nat, size: Nat, new_size: Nat) : Nat {
        if (address + size > self.size) {
            Debug.print(debug_show (address, size, self.size));
            return Debug.trap("MemoryRegion.deallocate(): memory block out of bounds");
        };

        // Debug.print("resizing " # debug_show (address, size, new_size));

        switch(FreeMemory.reclaim(self.free_memory, address, size, ?new_size)) {
            case (?new_address) {
                // Debug.print("reclaimed " # debug_show (address, size, new_size) # " at " # debug_show new_address);
                self.deallocated += size;
                self.deallocated -= new_size;
                return new_address;
            };
            case (null) self.deallocated += size;
        };

        allocate(self, new_size);
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
        ignore Region.grow(self.region, Nat64.fromNat(pages_to_allocate));
        self.pages += pages_to_allocate;
    };

    public func isFreed(self: MemoryRegion, address : Nat, size : Nat) : Result<Bool, Text> {
        FreeMemory.contains(self.free_memory, address, size);
    };

    /// Marks all the memory blocks in the region as deallocated.
    /// Note however that the data is not cleared and is only overwritten when it is reallocated.
    /// The size will be the total number deallocated bytes and the allocated bytes will be reset to 0.
    public func clear(self : MemoryRegion) {
        MaxBpTree.clear(self.free_memory);
        self.deallocated := self.size;
        MaxBpTree.clear(self.free_memory);
        ignore MaxBpTree.insert(self.free_memory, Cmp.Nat, Cmp.Nat, 0, self.size);
    };

    public func storeBlob(self : MemoryRegion, address : Nat, blob : Blob) {
        Region.storeBlob(self.region, Nat64.fromNat(address), blob);
    };

    public func addBlob(self : MemoryRegion, blob : Blob) : Nat {
        let address = allocate(self, blob.size());
        Region.storeBlob(self.region, Nat64.fromNat(address), blob);

        address;
    };

    public func loadBlob(self : MemoryRegion, address : Nat, size : Nat) : Blob {
        Region.loadBlob(self.region, Nat64.fromNat(address), size);
    };

    public func removeBlob(self : MemoryRegion, address : Nat, size : Nat) : Blob {
        let blob = Region.loadBlob(self.region, Nat64.fromNat(address), size);
        deallocate(self, address, size);

        blob;
    };

    public func replaceBlob(self : MemoryRegion, address : Nat, size : Nat, blob : Blob) : Blob {
        let old_blob = Region.loadBlob(self.region, Nat64.fromNat(address), size);

        let new_address = resize(self, address, size, blob.size());
        storeBlob(self, new_address, blob);

        old_blob;
    };

    public func addNat8(self : MemoryRegion, value : Nat8) : Nat {
        let address = allocate(self, 1);
        Region.storeNat8(self.region, Nat64.fromNat(address), value);

        address;
    };

    public func loadNat8(self : MemoryRegion, address : Nat) : Nat8 {
        Region.loadNat8(self.region, Nat64.fromNat(address));
    };

    public func storeNat8(self : MemoryRegion, address : Nat, value : Nat8) {
        Region.storeNat8(self.region, Nat64.fromNat(address), value);
    };

    public func removeNat8(self : MemoryRegion, address : Nat) : Nat8 {
        let nat8 = Region.loadNat8(self.region, Nat64.fromNat(address));
        deallocate(self, address, 1);

        nat8;
    };

    public func addNat16(self : MemoryRegion, value : Nat16) : Nat {
        let address = allocate(self, 2);
        Region.storeNat16(self.region, Nat64.fromNat(address), value);

        address;
    };

    public func loadNat16(self : MemoryRegion, address : Nat) : Nat16 {
        Region.loadNat16(self.region, Nat64.fromNat(address));
    };

    public func storeNat16(self : MemoryRegion, address : Nat, value : Nat16) {
        Region.storeNat16(self.region, Nat64.fromNat(address), value);
    };

    public func removeNat16(self : MemoryRegion, address : Nat) : Nat16 {
        let nat16 = Region.loadNat16(self.region, Nat64.fromNat(address));
        deallocate(self, address, 2);

        nat16;
    };

    public func addNat32(self : MemoryRegion, value : Nat32) : Nat {
        let address = allocate(self, 4);
        Region.storeNat32(self.region, Nat64.fromNat(address), value);

        address;
    };

    public func loadNat32(self : MemoryRegion, address : Nat) : Nat32 {
        Region.loadNat32(self.region, Nat64.fromNat(address));
    };

    public func storeNat32(self : MemoryRegion, address : Nat, value : Nat32) {
        Region.storeNat32(self.region, Nat64.fromNat(address), value);
    };

    public func removeNat32(self : MemoryRegion, address : Nat) : Nat32 {
        let nat32 = Region.loadNat32(self.region, Nat64.fromNat(address));
        deallocate(self, address, 4);

        nat32;
    };

    public func addNat64(self : MemoryRegion, value : Nat64) : Nat {
        let address = allocate(self, 8);
        Region.storeNat64(self.region, Nat64.fromNat(address), value);

        address;
    };

    public func loadNat64(self : MemoryRegion, address : Nat) : Nat64 {
        Region.loadNat64(self.region, Nat64.fromNat(address));
    };

    public func storeNat64(self : MemoryRegion, address : Nat, value : Nat64) {
        Region.storeNat64(self.region, Nat64.fromNat(address), value);
    };

    public func removeNat64(self : MemoryRegion, address : Nat) : Nat64 {
        let nat64 = Region.loadNat64(self.region, Nat64.fromNat(address));
        deallocate(self, address, 8);

        nat64;
    };

    public func addInt8(self : MemoryRegion, value : Int8) : Nat {
        let address = allocate(self, 1);
        Region.storeInt8(self.region, Nat64.fromNat(address), value);

        address;
    };

    public func loadInt8(self : MemoryRegion, address : Nat) : Int8 {
        Region.loadInt8(self.region, Nat64.fromNat(address));
    };

    public func storeInt8(self: MemoryRegion, address: Nat, value: Int8) {
        Region.storeInt8(self.region, Nat64.fromNat(address), value);
    };

    public func removeInt8(self : MemoryRegion, address : Nat) : Int8 {
        let int8 = Region.loadInt8(self.region, Nat64.fromNat(address));
        deallocate(self, address, 1);

        int8;
    };

    public func addInt16(self : MemoryRegion, value : Int16) : Nat {
        let address = allocate(self, 2);
        Region.storeInt16(self.region, Nat64.fromNat(address), value);

        address;
    };

    public func loadInt16(self : MemoryRegion, address : Nat) : Int16 {
        Region.loadInt16(self.region, Nat64.fromNat(address));
    };

    public func storeInt16(self: MemoryRegion, address: Nat, value: Int16) {
        Region.storeInt16(self.region, Nat64.fromNat(address), value);
    };

    public func removeInt16(self : MemoryRegion, address : Nat) : Int16 {
        let int16 = Region.loadInt16(self.region, Nat64.fromNat(address));
        deallocate(self, address, 2);

        int16;
    };

    public func addInt32(self : MemoryRegion, value : Int32) : Nat {
        let address = allocate(self, 4);
        Region.storeInt32(self.region, Nat64.fromNat(address), value);

        address;
    };

    public func storeInt32(self: MemoryRegion, address: Nat, value: Int32) {
        Region.storeInt32(self.region, Nat64.fromNat(address), value);
    };

    public func loadInt32(self : MemoryRegion, address : Nat) : Int32 {
        Region.loadInt32(self.region, Nat64.fromNat(address));
    };

    public func removeInt32(self : MemoryRegion, address : Nat) : Int32 {
        let int32 = Region.loadInt32(self.region, Nat64.fromNat(address));
        deallocate(self, address, 4);

        int32;
    };

    public func addInt64(self : MemoryRegion, value : Int64) : Nat {
        let address = allocate(self, 8);
        Region.storeInt64(self.region, Nat64.fromNat(address), value);

        address;
    };

    public func storeInt64(self: MemoryRegion, address: Nat, value: Int64) {
        Region.storeInt64(self.region, Nat64.fromNat(address), value);
    };

    public func loadInt64(self : MemoryRegion, address : Nat) : Int64 {
        Region.loadInt64(self.region, Nat64.fromNat(address));
    };

    public func removeInt64(self : MemoryRegion, address : Nat) : Int64 {
        let int64 = Region.loadInt64(self.region, Nat64.fromNat(address));
        deallocate(self, address, 8);

        int64;
    };

    // Todo: unsure about float size. could be 32 or 64 bits
    // public func addFloat(self : MemoryRegion, value : Float) : Nat {
    //     let address = allocate(self, 4); 
    //     Region.storeFloat(self.region, Nat64.fromNat(address), value);

    //     address;
    // };

};
