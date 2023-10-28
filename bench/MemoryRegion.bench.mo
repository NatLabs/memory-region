import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Region "mo:base/Region";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Prelude "mo:base/Prelude";

import Bench "mo:bench";

import MemoryRegion  "../src/MemoryRegion";

module {
    public func init() : Bench.Bench {
        let bench = Bench.Bench();

        bench.name("Region vs MemoryRegion");
        bench.description("Benchmarking the performance with 10k entries");

        bench.rows(["Region", "MemoryRegion"]);
        bench.cols(["addBlob()", "removeBlob()", "addBlob() after deallocating"]);

        let region : Region = Region.new();
        let memory_region = MemoryRegion.new();

        bench.runner(
            func(row, col) = switch (row, col) {

                case ("Region", "addBlob()") {

                    for (i in Iter.range(0, 9_999)){
                        if ((Nat64.toNat(Region.size(region)) * (2 ** 16)) < (i * 10) + 10) {
                            ignore Region.grow(region, 1);
                        };

                        Region.storeBlob(region, Nat64.fromNat(i * 10), "\ff\ff\ff\ff\ff\ff\ff\ff\ff\ff");
                    }
                };

                case ("Region", "removeBlob()" or "addBlob() after deallocating"){ };

                case ("MemoryRegion", "addBlob()" or "addBlob() after deallocating") {
                    for (i in Iter.range(0, 9_999)) {
                        ignore MemoryRegion.addBlob(memory_region, "\ff\ff\ff\ff\ff\ff\ff\ff\ff\ff");
                    };
                };

                case ("MemoryRegion", "removeBlob()"){
                    for (i in Iter.range(0, 9_999)) {
                        let double = i * 2;
                        let j = (double % 10_000) + (double / 10_000);
                        ignore MemoryRegion.removeBlob(memory_region, j * 10, 10);
                    };
                };

                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
