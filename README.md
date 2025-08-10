# Benchmark Results


No previous results found "/home/runner/work/memory-region/memory-region/.bench/MemoryRegion.bench.json"

<details>

<summary>bench/MemoryRegion.bench.mo $({\color{gray}0\%})$</summary>

### Region vs MemoryRegion

_Benchmarking the performance with 10k entries_


Instructions: ${\color{gray}0\\%}$
Heap: ${\color{gray}0\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{gray}0\\%}$


**Instructions**

|                                              | MemoryRegion | VersionedMemoryRegion |
| :------------------------------------------- | -----------: | --------------------: |
| allocate()                                   |    9_438_475 |             9_689_420 |
| deallocate()                                 |  164_367_062 |           160_686_101 |
| using allocate() to reallocate stored blocks |  260_600_203 |           271_940_285 |
| Preliminary Step: Sort Addresses             |  244_841_617 |           244_953_419 |
| deallocate() worst case                      |  205_864_832 |           204_618_931 |


**Heap**

|                                              | MemoryRegion | VersionedMemoryRegion |
| :------------------------------------------- | -----------: | --------------------: |
| allocate()                                   |    33.62 KiB |             33.61 KiB |
| deallocate()                                 |     1.49 MiB |               1.5 MiB |
| using allocate() to reallocate stored blocks |     5.51 MiB |              6.04 MiB |
| Preliminary Step: Sort Addresses             |     5.61 MiB |              5.62 MiB |
| deallocate() worst case                      |     1.64 MiB |              1.62 MiB |


**Garbage Collection**

|                                              | MemoryRegion | VersionedMemoryRegion |
| :------------------------------------------- | -----------: | --------------------: |
| allocate()                                   |          0 B |                   0 B |
| deallocate()                                 |          0 B |                   0 B |
| using allocate() to reallocate stored blocks |          0 B |                   0 B |
| Preliminary Step: Sort Addresses             |          0 B |                   0 B |
| deallocate() worst case                      |          0 B |                   0 B |


**Stable Memory**

|                                              | MemoryRegion | VersionedMemoryRegion |
| :------------------------------------------- | -----------: | --------------------: |
| allocate()                                   |       48 MiB |                48 MiB |
| deallocate()                                 |          0 B |                   0 B |
| using allocate() to reallocate stored blocks |       16 MiB |                24 MiB |
| Preliminary Step: Sort Addresses             |          0 B |                   0 B |
| deallocate() worst case                      |          0 B |                   0 B |

</details>
Saving results to .bench/MemoryRegion.bench.json
No previous results found "/home/runner/work/memory-region/memory-region/.bench/Merge.bench.json"

<details>

<summary>bench/Merge.bench.mo $({\color{gray}0\%})$</summary>

### MemoryRegion merge performance

_Benchmarking with 10k entries_


Instructions: ${\color{gray}0\\%}$
Heap: ${\color{gray}0\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{gray}0\\%}$


**Instructions**

|                     | MemoryRegion |
| :------------------ | -----------: |
| no merge (insert)   |  138_798_307 |
| merge prev          |  256_219_537 |
| merge next          |  137_026_116 |
| merge prev and next |  245_649_829 |


**Heap**

|                     | MemoryRegion |
| :------------------ | -----------: |
| no merge (insert)   |     1.57 MiB |
| merge prev          |     2.13 MiB |
| merge next          |     1.12 MiB |
| merge prev and next |     1.83 MiB |


**Garbage Collection**

|                     | MemoryRegion |
| :------------------ | -----------: |
| no merge (insert)   |          0 B |
| merge prev          |          0 B |
| merge next          |          0 B |
| merge prev and next |          0 B |


</details>
Saving results to .bench/Merge.bench.json
