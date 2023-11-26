// @testmode wasi
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Region "mo:base/Region";
import Nat "mo:base/Nat";
import BTree "mo:stableheapbtreemap/BTree";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";

import MemoryRegion "../src/MemoryRegion";
import Utils "../src/Utils";

suite(
    "MemoryRegion",
    func() {
        let limit = 5_000;

        let fuzzer = Fuzz.fromSeed(0);
        let memory_region = MemoryRegion.new();
        let pointers = Buffer.Buffer<MemoryRegion.Pointer>(limit * 2);
        let blobs = Buffer.Buffer<Blob>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let size = fuzzer.nat.randomRange(1, 100);
            let blob = fuzzer.blob.randomBlob(size);
            blobs.add(blob);
        };

        test(
            "allocation and size_info",
            func() {

                var prev_size = 0;
                var adr = 0;

                for (i in Iter.range(0, limit - 1)) {
                    let bytes = fuzzer.nat.randomRange(1, 100);

                    let address = MemoryRegion.allocate(memory_region, bytes) else return assert false;
                    assert address == prev_size;
                    pointers.add((address, bytes));

                    prev_size += bytes;
                };

                let size = prev_size;

                assert MemoryRegion.size_info(memory_region) == {
                    size;
                    allocated = size;
                    deallocated = 0;
                    pages = Utils.div_ceil(size, 64 * 1024);
                    capacity = Utils.div_ceil(size, 64 * 1024) * 64 * 1024;
                };

                assert MemoryRegion.getFreeMemory(memory_region) == [];
            },
        );

        assert pointers.size() == limit;

        test("addBlob()", func (){

            let last_pointer = Buffer.last(pointers);
            var expected_address = last_pointer.0 + last_pointer.1;

            for (blob in blobs.vals()) {
                let address = MemoryRegion.addBlob(memory_region, blob);

                assert address == expected_address;
                pointers.add((address, blob.size()));

                expected_address += blob.size();
            };

            assert MemoryRegion.getFreeMemory(memory_region) == [];

        });

        assert pointers.size() == limit * 2;

        test(
            "deallocate every 2nd memory block",
            func() {

                var skipped_address = limit + 1; // avoids starting at 0 because that is the first freed memory block

                var i = 0;

                while (i < limit){
                    let (address, size) = pointers.get(i);

                    MemoryRegion.deallocate(memory_region, address, size);

                    switch (BTree.get(memory_region.free_memory.addresses, Nat.compare, address)) {
                        case (?retrieved_size) {
                            if (not (retrieved_size == size)) {
                                Debug.print("(address, size) " # debug_show (address, size));
                                Debug.print("retrieved " # debug_show (address, retrieved_size));
                                Debug.trap("actual size does not match retrieved size " # debug_show MemoryRegion.getFreeMemory(memory_region));
                            };
                        };
                        case (_) Debug.trap("Did not deallocate memory block");
                    };

                    if (BTree.has(memory_region.free_memory.addresses, Nat.compare, skipped_address)) {
                        Debug.trap("Included skipped address in free memory map " # debug_show (address, size));
                    };

                    skipped_address := (address + size);
                    i+=2;
                };
            },
        );

        test(
            "deallocate and merge adjacent memory blocks",
            func() {
                var start_address = 0;
                var merged_size = pointers.get(0).1;

                var i = 1;

                while (i < limit){
                    let (address, size) = pointers.get(i);
                    MemoryRegion.deallocate(memory_region, address, size);

                    if (BTree.has(memory_region.free_memory.addresses, Nat.compare, address)) {
                        Debug.trap("Included the freed memory block instead of merging " # debug_show (address, size) # " with " # debug_show (start_address, merged_size));
                    };

                    let next = pointers.get(i + 1);

                    switch (BTree.get(memory_region.free_memory.addresses, Nat.compare, start_address)) {
                        case (?retrieved_size) {
                            if (i + 1 < limit){
                                if (not (retrieved_size == (merged_size + size + next.1))) {
                                    Debug.print("(prev, curr, next) " # debug_show ((start_address, merged_size), (address, size), next));
                                    Debug.print("retrieved " # debug_show (start_address, retrieved_size));
                                    Debug.trap("Did not merge freed memory block " # debug_show MemoryRegion.getFreeMemory(memory_region));
                                };
                                
                                merged_size += size + next.1;
                            }else {
                                if (not (retrieved_size == (merged_size + size))) {
                                    Debug.print("(prev, curr) " # debug_show ((start_address, merged_size), (address, size)));
                                    Debug.print("retrieved " # debug_show (start_address, retrieved_size));
                                    Debug.trap("Did not merge freed memory block " # debug_show MemoryRegion.getFreeMemory(memory_region));
                                };

                                merged_size += size;
                            }
                        };
                        case (_) Debug.trap("Did not merge next free memory block with previous one");
                    };

                    i += 2;
                };

                assert MemoryRegion.getFreeMemory(memory_region) == [(start_address, merged_size)];
            },
        );



        var i = 0;
        Buffer.reverse(pointers);

        for (i in Iter.range(0, limit - 1)){
            ignore pointers.removeLast();
        };

        Buffer.reverse(pointers);
        
        assert pointers.size() == limit;

        test("removeBlob() reallocate memory blocks", func(){

            let first_pointer = pointers.get(0);

            for (i in Iter.range(0, limit - 1)){
                let (address, size) = pointers.get(i);
                let expected_blob = blobs.get(i);

                assert expected_blob.size() == size;

                let blob = MemoryRegion.removeBlob(memory_region, address, size);

                if (not (expected_blob == blob)) {
                    Debug.print("(expected, received) " # debug_show (expected_blob, blob) # " at index " # debug_show i);
                };

                assert expected_blob == blob;
            };
        })
    },
);
