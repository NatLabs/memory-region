// @testmode wasi
import { test; suite } "mo:test";
import MemoryRegionV0 "mo:memory-region-v0_1_1/MemoryRegion";

import MemoryRegion "../src/MemoryRegion";
import VersionedMemoryRegion "../src/VersionedMemoryRegion";
import Migrations "../src/Migrations";

type VersionedMemoryRegion = VersionedMemoryRegion.VersionedMemoryRegion;

suite(
    "MemoryRegion Migration",
    func() {
        test("deploys current version", func (){
            let vs_memory_region = VersionedMemoryRegion.new();
            ignore Migrations.getCurrentVersion(vs_memory_region); // should not trap

            let memory_region = MemoryRegion.new();
            let version = MemoryRegion.toVersioned(memory_region);
            ignore Migrations.getCurrentVersion(version); // should not trap
        });

        test("migrates (v0 -> v1) successfully", func (){
            let memory_region = MemoryRegionV0.new();
            var vs_memory_region : VersionedMemoryRegion = #v0(memory_region);

            ignore MemoryRegionV0.allocate(memory_region, 1000);
            MemoryRegionV0.deallocate(memory_region, 100, 35);
            MemoryRegionV0.deallocate(memory_region, 200, 50);
            MemoryRegionV0.deallocate(memory_region, 300, 70);

            let v0_memory_info = MemoryRegionV0.size_info(memory_region);
            assert v0_memory_info.size == 1000;
            assert v0_memory_info.deallocated == 155;
            assert v0_memory_info.allocated == 1000 - 155;

            vs_memory_region := VersionedMemoryRegion.upgrade(vs_memory_region);

            let v1_memory_info = {
                size = VersionedMemoryRegion.size(vs_memory_region);
                deallocated = VersionedMemoryRegion.deallocated(vs_memory_region);
                allocated = VersionedMemoryRegion.allocated(vs_memory_region);
                pages = VersionedMemoryRegion.pages(vs_memory_region);
                capacity = VersionedMemoryRegion.capacity(vs_memory_region);
            };

            assert v1_memory_info == v0_memory_info;

            assert MemoryRegionV0.getFreeMemory(memory_region) == VersionedMemoryRegion.getFreeMemory(vs_memory_region);
        });
    }
)