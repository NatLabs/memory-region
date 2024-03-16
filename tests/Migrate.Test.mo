import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Region "mo:base/Region";
import Nat "mo:base/Nat";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";
import MaxBpTree "mo:augmented-btrees/MaxBpTree";
import Cmp "mo:augmented-btrees/Cmp";
import MaxBpTreeMethods "mo:augmented-btrees/MaxBpTree/Methods";

import Itertools "mo:itertools/Iter";

import MemoryRegion "../src/MemoryRegion";
import VersionedMemoryRegion "../src/VersionedMemoryRegion";
import Migrations "../src/Migrations";
import Utils "../src/Utils";

suite(
    "MemoryRegion Migration",
    func() {
        test("deploys current version", func (){
            let vs_memory_region = VersionedMemoryRegion.new();
            ignore Migrations.getCurrentVersion(vs_memory_region); // should not trap

            let memory_region = MemoryRegion.new();
            let version = MemoryRegion.shareVersion(memory_region);
            ignore Migrations.getCurrentVersion(version); // should not trap
        })
    }
)