Benchmark files:
• bench/MemoryRegion.bench.mo
• bench/Merge.bench.mo

==================================================

Starting dfx replica...
Deploying canisters...

——————————————————————————————————————————————————

Running bench/MemoryRegion.bench.mo...

			

Stable Memory

|                                              | MemoryRegion | VersionedMemoryR
egion |
| :------------------------------------------- | -----------: | ----------------
----: |
| allocate()                                   |  48 MiB (0%) |           48 MiB
 (0%) |
| deallocate()                                 |   0 B (NaN%) |            0 B (
NaN%) |
| using allocate() to reallocate stored blocks |  16 MiB (0%) |           24 MiB
 (0%) |
| Preliminary Step: Sort Addresses             |   0 B (NaN%) |            0 B (
NaN%) |
| deallocate() worst case                      |   0 B (NaN%) |            0 B (
NaN%) |
			

Garbage Collection

|                                              | MemoryRegion | VersionedMemoryR
egion |
| :------------------------------------------- | -----------: | ----------------
----: |
| allocate()                                   |   0 B (NaN%) |            0 B (
NaN%) |
| deallocate()                                 |   0 B (NaN%) |            0 B (
NaN%) |
| using allocate() to reallocate stored blocks |   0 B (NaN%) |            0 B (
NaN%) |
| Preliminary Step: Sort Addresses             |   0 B (NaN%) |            0 B (
NaN%) |
| deallocate() worst case                      |   0 B (NaN%) |            0 B (
NaN%) |
		
Saving results to .bench/MemoryRegion.bench.json

——————————————————————————————————————————————————

Running bench/Merge.bench.mo...

| merge next          |     1.12 MiB (0%) |
| merge prev and next | 1.84 MiB (+0.68%) |
			

Stable Memory

|                     | MemoryRegion |
| :------------------ | -----------: |
| no merge (insert)   |   0 B (NaN%) |
| merge prev          |   0 B (NaN%) |
| merge next          |   0 B (NaN%) |
| merge prev and next |   0 B (NaN%) |
			

Garbage Collection

|                     | MemoryRegion |
| :------------------ | -----------: |
| no merge (insert)   |   0 B (NaN%) |
| merge prev          |   0 B (NaN%) |
| merge next          |   0 B (NaN%) |
| merge prev and next |   0 B (NaN%) |
		
Saving results to .bench/Merge.bench.json
Stopping replica...
