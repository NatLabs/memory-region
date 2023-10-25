import Prim "mo:prim";
import Cycles "mo:base/ExperimentalCycles";
import IC "mo:base/ExperimentalInternetComputer";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Region "mo:base/Region";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";

import { MemoryRegion } "../src";

actor {

    type Benchmark = {
        calls: Nat64;
        heap: Nat;
        memory: Nat;
    };

    func current_benchmarks(): Benchmark {
        {
            calls = 0;
            heap = Prim.rts_heap_size();
            memory = Prim.rts_memory_size();
        }
    };

    func benchmark(fn: () -> ()): Benchmark {

        let init_heap = Prim.rts_heap_size();
        let init_memory = Prim.rts_memory_size();

        let calls = IC.countInstructions(fn);
        
        {
            calls;
            heap = Prim.rts_heap_size() - init_heap;
            memory = Prim.rts_memory_size() - init_memory;
        }
    };

    public query func test_region(n: Nat): async [(Text, Benchmark)]{
        let init_benchmark = ("before", current_benchmarks());

        let region : Region = Region.new();

        let add_benchmark = ("add()", benchmark(
            func() {
                for (i in Iter.range(0, n- 1)){
                    if ((Nat64.toNat(Region.size(region)) * (2 ** 16)) < (i * 10) + 10 ){
                        Debug.print("Growing normal region");
                        ignore Region.grow(region, 1);
                    };

                    Region.storeBlob(region, Nat64.fromNat(i * 10), "\ff\ff\ff\ff\ff\ff\ff\ff\ff\ff");
                }
            }
        ));


        return [
            init_benchmark,
            add_benchmark,
            ("all", current_benchmarks())
        ]
    };
    
    public query func test_mem_buffer(n: Nat) : async [(Text, Benchmark)] {
        
        let init_benchmark = ("init", current_benchmarks());

        let memory_region = MemoryRegion.new();

        let add_benchmark = ("add()", benchmark(
            func() {
                for (i in Iter.range(0, n - 1)){
                    ignore MemoryRegion.addBlob(memory_region, "\ff\ff\ff\ff\ff\ff\ff\ff\ff\ff");
                }
            }
        ));

 

        return [
            init_benchmark,
            add_benchmark,
            ("all", current_benchmarks())
        ];
    };
};
