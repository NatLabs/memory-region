# Benchmark Results



<details>

<summary>bench/MemoryRegion.bench.mo $({\color{gray}0\%})$</summary>

### Region vs MemoryRegion

_Benchmarking the performance with 10k entries_


Instructions: ${\color{gray}0\\%}$
Heap: ${\color{gray}0\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{gray}0\\%}$


**Instructions**

|                                              |                       MemoryRegion |              VersionedMemoryRegion |
| :------------------------------------------- | ---------------------------------: | ---------------------------------: |
| allocate()                                   |   9_438_475 $({\color{gray}0\\%})$ |   9_689_420 $({\color{gray}0\\%})$ |
| deallocate()                                 | 164_367_062 $({\color{gray}0\\%})$ | 160_686_101 $({\color{gray}0\\%})$ |
| using allocate() to reallocate stored blocks | 260_600_203 $({\color{gray}0\\%})$ | 271_940_285 $({\color{gray}0\\%})$ |
| Preliminary Step: Sort Addresses             | 244_841_617 $({\color{gray}0\\%})$ | 244_953_419 $({\color{gray}0\\%})$ |
| deallocate() worst case                      | 205_864_832 $({\color{gray}0\\%})$ | 204_618_931 $({\color{gray}0\\%})$ |


**Heap**

|                                              |                     MemoryRegion |            VersionedMemoryRegion |
| :------------------------------------------- | -------------------------------: | -------------------------------: |
| allocate()                                   | 33.62 KiB $({\color{gray}0\\%})$ | 33.61 KiB $({\color{gray}0\\%})$ |
| deallocate()                                 |  1.49 MiB $({\color{gray}0\\%})$ |   1.5 MiB $({\color{gray}0\\%})$ |
| using allocate() to reallocate stored blocks |  5.51 MiB $({\color{gray}0\\%})$ |  6.04 MiB $({\color{gray}0\\%})$ |
| Preliminary Step: Sort Addresses             |  5.61 MiB $({\color{gray}0\\%})$ |  5.62 MiB $({\color{gray}0\\%})$ |
| deallocate() worst case                      |  1.64 MiB $({\color{gray}0\\%})$ |  1.62 MiB $({\color{gray}0\\%})$ |


**Garbage Collection**

|                                              |               MemoryRegion |      VersionedMemoryRegion |
| :------------------------------------------- | -------------------------: | -------------------------: |
| allocate()                                   | 0 B $({\color{gray}0\\%})$ | 0 B $({\color{gray}0\\%})$ |
| deallocate()                                 | 0 B $({\color{gray}0\\%})$ | 0 B $({\color{gray}0\\%})$ |
| using allocate() to reallocate stored blocks | 0 B $({\color{gray}0\\%})$ | 0 B $({\color{gray}0\\%})$ |
| Preliminary Step: Sort Addresses             | 0 B $({\color{gray}0\\%})$ | 0 B $({\color{gray}0\\%})$ |
| deallocate() worst case                      | 0 B $({\color{gray}0\\%})$ | 0 B $({\color{gray}0\\%})$ |


**Stable Memory**

|                                              |                  MemoryRegion |         VersionedMemoryRegion |
| :------------------------------------------- | ----------------------------: | ----------------------------: |
| allocate()                                   | 48 MiB $({\color{gray}0\\%})$ | 48 MiB $({\color{gray}0\\%})$ |
| deallocate()                                 |    0 B $({\color{gray}0\\%})$ |    0 B $({\color{gray}0\\%})$ |
| using allocate() to reallocate stored blocks | 16 MiB $({\color{gray}0\\%})$ | 24 MiB $({\color{gray}0\\%})$ |
| Preliminary Step: Sort Addresses             |    0 B $({\color{gray}0\\%})$ |    0 B $({\color{gray}0\\%})$ |
| deallocate() worst case                      |    0 B $({\color{gray}0\\%})$ |    0 B $({\color{gray}0\\%})$ |

</details>
Saving results to .bench/MemoryRegion.bench.json

<details>

<summary>bench/Merge.bench.mo $({\color{red}+0.04\%})$</summary>

### MemoryRegion merge performance

_Benchmarking with 10k entries_


Instructions: ${\color{red}+0.02\\%}$
Heap: ${\color{red}+0.01\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{gray}0\\%}$


**Instructions**

|                     |                            MemoryRegion |
| :------------------ | --------------------------------------: |
| no merge (insert)   |   138_862_119 $({\color{red}+0.04\\%})$ |
| merge prev          |   255_899_893 $({\color{red}+0.04\\%})$ |
| merge next          |   137_012_822 $({\color{red}+0.04\\%})$ |
| merge prev and next | 245_631_916 $({\color{green}-0.02\\%})$ |


**Heap**

|                     |                         MemoryRegion |
| :------------------ | -----------------------------------: |
| no merge (insert)   | 1.58 MiB $({\color{green}-0.02\\%})$ |
| merge prev          |   2.13 MiB $({\color{red}+0.15\\%})$ |
| merge next          |      1.12 MiB $({\color{gray}0\\%})$ |
| merge prev and next | 1.82 MiB $({\color{green}-0.08\\%})$ |


**Garbage Collection**

|                     |               MemoryRegion |
| :------------------ | -------------------------: |
| no merge (insert)   | 0 B $({\color{gray}0\\%})$ |
| merge prev          | 0 B $({\color{gray}0\\%})$ |
| merge next          | 0 B $({\color{gray}0\\%})$ |
| merge prev and next | 0 B $({\color{gray}0\\%})$ |


</details>
Saving results to .bench/Merge.bench.json
