import Region "mo:base/Region";
import Result "mo:base/Result";

import FreeMemory "FreeMemory";
import Migrations "Migrations";
import MemoryRegion "MemoryRegion";

module VersionedMemoryRegion {

    public type Pointer = (address : Nat, size : Nat);
    type Result<T, E> = Result.Result<T, E>;

    public type FreeMemory = FreeMemory.FreeMemory;

    public type MemoryRegion = Migrations.CurrentMemoryRegion;
    public type VersionedMemoryRegion = Migrations.VersionedMemoryRegion;

    public type MemoryInfo = MemoryRegion.MemoryInfo;

    public let PageSize : Nat = MemoryRegion.PageSize;

    public func new() : VersionedMemoryRegion {
        #v1(MemoryRegion.new());
    };

    /// Migrate a memory region to the latest version.
    public func upgrade(versions: VersionedMemoryRegion) : VersionedMemoryRegion {
        Migrations.upgrade(versions);
    };

    public func getFreeMemory(versions : VersionedMemoryRegion) : [(Nat, Nat)] {
        let state = Migrations.getCurrentVersion(versions);
        FreeMemory.toArray(state.free_memory);
    };

    /// Total number of bytes allocated including deallocated bytes.
    public func size(versions : VersionedMemoryRegion) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        state.size;
    };

    /// Returns the id of the Region.
    public func id(versions: VersionedMemoryRegion) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        Region.id(state.region);
    };

    /// Total number of bytes available before the allocator needs to grow.
    public func capacity(versions : VersionedMemoryRegion) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        state.pages * PageSize;
    };

    /// Number of pages allocated. (1 page = 64KB)
    public func pages(versions : VersionedMemoryRegion) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        state.pages;
    };

    /// Total number of bytes allocated and in use.
    public func allocated(versions : VersionedMemoryRegion) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        (state.size - state.deallocated) : Nat;
    };

    /// Total number of bytes deallocated.
    public func deallocated(versions : VersionedMemoryRegion) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        state.deallocated;
    };

    /// Information about the memory usage of the region.
    public func memoryInfo(versions : VersionedMemoryRegion) : MemoryInfo {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.memoryInfo(state);
    };

    public func deallocate(versions : VersionedMemoryRegion, address : Nat, size : Nat) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.deallocate(state, address, size);
    };

    public func allocate(versions : VersionedMemoryRegion, bytes : Nat) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.allocate(state, bytes);
    };

    /// Tries to resize a memory block. 
    /// If it is not possible it deallocates the block and allocates a new one.
    /// As a result it is be best to assume that the address of the memory block will change after a resize.
    public func resize(versions: VersionedMemoryRegion, address: Nat, size: Nat, new_size: Nat) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.resize(state, address, size, new_size);
    };

    public func grow(versions : VersionedMemoryRegion, pages : Nat) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.grow(state, pages);
    };

    /// Grows the memory region if needed to allocate the given number of `bytes`.
    public func growIfNeeded(versions : VersionedMemoryRegion, bytes : Nat) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.growIfNeeded(state, bytes);
    };

    public func isFreed(versions: VersionedMemoryRegion, address : Nat, size : Nat) : Result<Bool, Text> {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.isFreed(state, address, size);
    };

    /// Resets the memory region to its initial state.
    public func clear(versions : VersionedMemoryRegion) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.clear(state);
    };

    public func storeBlob(versions : VersionedMemoryRegion, address : Nat, blob : Blob) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.storeBlob(state, address, blob);
    };

    public func addBlob(versions : VersionedMemoryRegion, blob : Blob) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.addBlob(state, blob);
    };

    public func loadBlob(versions : VersionedMemoryRegion, address : Nat, size : Nat) : Blob {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.loadBlob(state, address, size);
    };

    public func removeBlob(versions : VersionedMemoryRegion, address : Nat, size : Nat) : Blob {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.removeBlob(state, address, size);
    };

    public func replaceBlob(versions : VersionedMemoryRegion, address : Nat, size : Nat, blob : Blob) : Blob {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.replaceBlob(state, address, size, blob);
     };

    public func addNat8(versions : VersionedMemoryRegion, value : Nat8) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.addNat8(state, value);
    };

    public func loadNat8(versions : VersionedMemoryRegion, address : Nat) : Nat8 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.loadNat8(state, address);
    };

    public func storeNat8(versions : VersionedMemoryRegion, address : Nat, value : Nat8) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.storeNat8(state, address, value);
    };

    public func removeNat8(versions : VersionedMemoryRegion, address : Nat) : Nat8 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.removeNat8(state, address);
    };

    public func addNat16(versions : VersionedMemoryRegion, value : Nat16) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.addNat16(state, value);
    };

    public func loadNat16(versions : VersionedMemoryRegion, address : Nat) : Nat16 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.loadNat16(state, address);
    };

    public func storeNat16(versions : VersionedMemoryRegion, address : Nat, value : Nat16) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.storeNat16(state, address, value);
    };

    public func removeNat16(versions : VersionedMemoryRegion, address : Nat) : Nat16 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.removeNat16(state, address);
    };

    public func addNat32(versions : VersionedMemoryRegion, value : Nat32) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.addNat32(state, value);
    };

    public func loadNat32(versions : VersionedMemoryRegion, address : Nat) : Nat32 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.loadNat32(state, address);
    };

    public func storeNat32(versions : VersionedMemoryRegion, address : Nat, value : Nat32) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.storeNat32(state, address, value);
    };

    public func removeNat32(versions : VersionedMemoryRegion, address : Nat) : Nat32 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.removeNat32(state, address);
    };

    public func addNat64(versions : VersionedMemoryRegion, value : Nat64) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.addNat64(state, value);
    };

    public func loadNat64(versions : VersionedMemoryRegion, address : Nat) : Nat64 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.loadNat64(state, address);
    };

    public func storeNat64(versions : VersionedMemoryRegion, address : Nat, value : Nat64) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.storeNat64(state, address, value);
    };

    public func removeNat64(versions : VersionedMemoryRegion, address : Nat) : Nat64 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.removeNat64(state, address);
    };

    public func addInt8(versions : VersionedMemoryRegion, value : Int8) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.addInt8(state, value);
    };

    public func loadInt8(versions : VersionedMemoryRegion, address : Nat) : Int8 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.loadInt8(state, address);
    };

    public func storeInt8(versions: VersionedMemoryRegion, address: Nat, value: Int8) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.storeInt8(state, address, value);
    };

    public func removeInt8(versions : VersionedMemoryRegion, address : Nat) : Int8 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.removeInt8(state, address);
    };

    public func addInt16(versions : VersionedMemoryRegion, value : Int16) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.addInt16(state, value);
    };

    public func loadInt16(versions : VersionedMemoryRegion, address : Nat) : Int16 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.loadInt16(state, address);
    };

    public func storeInt16(versions: VersionedMemoryRegion, address: Nat, value: Int16) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.storeInt16(state, address, value);
    };

    public func removeInt16(versions : VersionedMemoryRegion, address : Nat) : Int16 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.removeInt16(state, address);
    };

    public func addInt32(versions : VersionedMemoryRegion, value : Int32) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.addInt32(state, value);
    };

    public func storeInt32(versions: VersionedMemoryRegion, address: Nat, value: Int32) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.storeInt32(state, address, value);
    };

    public func loadInt32(versions : VersionedMemoryRegion, address : Nat) : Int32 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.loadInt32(state, address);
    };

    public func removeInt32(versions : VersionedMemoryRegion, address : Nat) : Int32 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.removeInt32(state, address);
    };

    public func addInt64(versions : VersionedMemoryRegion, value : Int64) : Nat {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.addInt64(state, value);
    };

    public func storeInt64(versions: VersionedMemoryRegion, address: Nat, value: Int64) {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.storeInt64(state, address, value);
    };

    public func loadInt64(versions : VersionedMemoryRegion, address : Nat) : Int64 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.loadInt64(state, address);
    };

    public func removeInt64(versions : VersionedMemoryRegion, address : Nat) : Int64 {
        let state = Migrations.getCurrentVersion(versions);
        MemoryRegion.removeInt64(state, address);
    };

    // Todo: unsure about float size. could be 32 or 64 bits
    // public func addFloat(versions : VersionedMemoryRegion, value : Float) : Nat {
    //     let state = Migrations.getCurrentVersion(versions);
    //     MemoryRegion.addFloat(state, value);
    // };

};
