## Legacy (Dual B+ Tree)
Instructions

|              |  addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :----------- | ---------: | -----------: | ---------------------: | ----------------------: |
| Region       |  9_257_218 |        2_006 |                  2_641 |                   2_953 |
| MemoryRegion | 12_907_110 |  277_833_787 |            180_610_269 |             326_408_676 |


Heap

|              | addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :----------- | --------: | -----------: | ---------------------: | ----------------------: |
| Region       |     9_200 |        8_952 |                  8_952 |                   8_952 |
| MemoryRegion |     9_140 |    4_384_188 |              3_093_220 |               5_026_240 |

## Update (Max B+ Tree)

Instructions

|              |  addBlob() | removeBlob() | addBlob() reallocation | removeBlob() merge blocks |
| :----------- | ---------: | -----------: | ---------------------: | ------------------------: |
| Region       |  9_259_160 |        2_006 |                  2_641 |                     2_999 |
| MemoryRegion | 11_649_052 |  234_483_711 |             49_831_184 |               528_619_507 |


Heap

|              | addBlob() | removeBlob() | addBlob() reallocation | removeBlob() merge blocks |
| :----------- | --------: | -----------: | ---------------------: | ------------------------: |
| Region       |     9_200 |        8_952 |                  8_952 |                     8_952 |
| MemoryRegion |     9_140 |    3_508_532 |              3_009_008 |                 5_571_196 |

**Merge performance**

| Instructions | no merge (insert) |  merge prev |  merge next | merge prev and next |
| :----------- | ----------------: | ----------: | ----------: | ------------------: |
| MemoryRegion |       189_561_797 | 357_256_324 | 239_947_476 |         363_515_972 |


| Heap         | no merge (insert) | merge prev | merge next | merge prev and next |
| :----------- | ----------------: | ---------: | ---------: | ------------------: |
| MemoryRegion |         2_831_860 |  5_736_844 |  3_296_768 |         -26_041_692 |

#### Max B+Tree with optimized merge

| Instructions |  addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :----------- | ---------: | -----------: | ---------------------: | ----------------------: |
| Region       |  9_261_286 |        2_006 |                  2_641 |                   2_953 |
| MemoryRegion | 11_651_178 |  167_539_453 |             53_136_702 |             201_801_312 |


| Heap         | addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :----------- | --------: | -----------: | ---------------------: | ----------------------: |
| Region       |     9_200 |        8_952 |                  8_952 |                   8_952 |
| MemoryRegion |     9_140 |    4_722_336 |              3_129_008 |               5_033_280 |

**Merge performance**

Instructions

|              | no merge (insert) |  merge prev |  merge next | merge prev and next |
| :----------- | ----------------: | ----------: | ----------: | ------------------: |
| MemoryRegion |       168_761_373 | 146_197_637 | 145_691_915 |         242_789_451 |


Heap

|              | no merge (insert) | merge prev | merge next | merge prev and next |
| :----------- | ----------------: | ---------: | ---------: | ------------------: |
| MemoryRegion |         2_912_068 |  4_837_392 |  4_834_164 |         -25_935_780 |


#### Max B+Tree with compact tuple structure and Int8 comparators
|              |  addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :----------- | ---------: | -----------: | ---------------------: | ----------------------: |
| Region       |  9_260_699 |        2_006 |                  2_641 |                   2_953 |
| MemoryRegion | 11_350_591 |  140_043_805 |             47_321_032 |             168_822_364 |


Heap

|              | addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :----------- | --------: | -----------: | ---------------------: | ----------------------: |
| Region       |     9_200 |        8_952 |                  8_952 |                   8_952 |
| MemoryRegion |     9_140 |    2_846_132 |              2_489_008 |               2_918_600 |


**Merge performance**


Instructions

|              | no merge (insert) |  merge prev |  merge next | merge prev and next |
| :----------- | ----------------: | ----------: | ----------: | ------------------: |
| MemoryRegion |       146_107_101 | 115_621_557 | 114_974_600 |         204_072_755 |


Heap

|              | no merge (insert) | merge prev | merge next | merge prev and next |
| :----------- | ----------------: | ---------: | ---------: | ------------------: |
| MemoryRegion |         1_422_172 |  2_490_416 |  2_485_616 |           3_162_376 |


#### Fixed issues with internal functions in Max B+ Tree

Instructions

|              |  addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :----------- | ---------: | -----------: | ---------------------: | ----------------------: |
| Region       |  9_254_356 |        2_006 |                  2_641 |                   2_953 |
| MemoryRegion | 11_344_248 |  123_146_538 |             47_648_854 |             150_202_099 |


Heap

|              | addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :----------- | --------: | -----------: | ---------------------: | ----------------------: |
| Region       |     9_200 |        8_952 |                  8_952 |                   8_952 |
| MemoryRegion |     9_140 |    2_319_428 |              2_717_352 |               2_446_108 |

**Merge performance**

Instructions

|              | no merge (insert) |  merge prev |  merge next | merge prev and next |
| :----------- | ----------------: | ----------: | ----------: | ------------------: |
| MemoryRegion |       101_515_261 | 104_617_643 | 103_760_605 |         195_021_097 |


Heap

|              | no merge (insert) | merge prev | merge next | merge prev and next |
| :----------- | ----------------: | ---------: | ---------: | ------------------: |
| MemoryRegion |         1_102_572 |  1_650_156 |  1_645_236 |           2_522_336 |

#### MaxBpTree Optimization + VersionedMemoryRegion

Instructions

|                       |  addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :-------------------- | ---------: | -----------: | ---------------------: | ----------------------: |
| Region                |  9_258_916 |        2_011 |                  2_646 |                   2_958 |
| MemoryRegion          | 11_038_808 |  120_867_124 |             39_782_232 |             141_676_905 |
| VersionedMemoryRegion | 11_379_905 |  121_218_428 |             40_123_743 |             142_028_623 |

Heap

|                       | addBlob() | removeBlob() | addBlob() reallocation | removeBlob() worst case |
| :-------------------- | --------: | -----------: | ---------------------: | ----------------------: |
| Region                |     9_152 |        8_904 |                  8_904 |                   8_904 |
| MemoryRegion          |     9_092 |    2_140_716 |              1_688_384 |               2_260_224 |
| VersionedMemoryRegion |     9_092 |    2_140_716 |              1_688_384 |               2_260_224 |

**Merge performance**

Instructions

|              | no merge (insert) |  merge prev |  merge next | merge prev and next |
| :----------- | ----------------: | ----------: | ----------: | ------------------: |
| MemoryRegion |       101_177_532 | 100_951_767 | 100_511_055 |         189_091_747 |


Heap

|              | no merge (insert) | merge prev | merge next | merge prev and next |
| :----------- | ----------------: | ---------: | ---------: | ------------------: |
| MemoryRegion |         1_433_164 |  1_337_168 |  1_337_168 |           2_072_392 |