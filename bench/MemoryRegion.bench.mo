import Prim "mo:prim";
import Cycles "mo:base/ExperimentalCycles";
import IC "mo:base/ExperimentalInternetComputer";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Region "mo:base/Region";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Bench "mo:bench";
import Nat "mo:base/Nat";
import Prelude "mo:base/Prelude";

import MemoryRegion  "../src/MemoryRegion";

module {
    public func init() : Bench.Bench {
        let bench = Bench.Bench();

        bench.name("Region vs MemoryRegion");
        bench.description("Benchmarking the performance with 100k entries");

        bench.rows(["Region", "MemoryRegion"]);
        bench.cols(["addBlob()", "removeBlob()"]);

        bench.runner(
            func(row, col) = switch (row) {
                case ("Region") {
                    let region : Region = Region.new();

                    for (i in Iter.range(0, 99_999)){
                        if ((Nat64.toNat(Region.size(region)) * (2 ** 16)) < (i * 10) + 10) {
                            Debug.print("Growing normal region");
                            ignore Region.grow(region, 1);
                        };

                        Region.storeBlob(region, Nat64.fromNat(i * 10), "\ff\ff\ff\ff\ff\ff\ff\ff\ff\ff");
                    }
                    
                };

                case ("MemoryRegion") {
                    let memory_region = MemoryRegion.new();

                    for (i in Iter.range(0, 99_999)) {
                        ignore MemoryRegion.addBlob(memory_region, "\ff\ff\ff\ff\ff\ff\ff\ff\ff\ff");
                    };
                };

                case (_) Prelude.unreachable();
            }
        );

        bench;
    };
};
