## m = 32 (base)
|              |  addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | ---------: | -----------: | ---------------------------: |
| Region       |  7_219_214 |        1_949 |                        2_717 |
| MemoryRegion | 11_380_427 |  171_654_817 |                  152_081_540 |

Instructions

|              |       addBlob() |         removeBlob() | addBlob() after dea
llocating |
| :----------- | --------------: | -------------------: | -------------------
--------: |
| Region       |  7_219_214 (0%) |           1_949 (0%) |                   2
_717 (0%) |
| MemoryRegion | 11_380_427 (0%) | 167_714_468 (-2.30%) |             152_081
_540 (0%) |

## m = 32 (after improvements)
Heap

|              |  addBlob() |        removeBlob() | addBlob() after deallocat
ing |
| :----------- | ---------: | ------------------: | -------------------------
--: |
| Region       | 9_040 (0%) |          8_952 (0%) |                   8_952 (
0%) |
| MemoryRegion | 9_040 (0%) | 2_812_120 (-12.50%) |               3_168_140 (
0%) |

Heap

|              | addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | --------: | -----------: | ---------------------------: |
| Region       |     9_040 |        8_952 |                        8_952 |
| MemoryRegion |     9_040 |    3_213_880 |                    3_168_140 |

## m = 4

Instructions

|              |  addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | ---------: | -----------: | ---------------------------: |
| Region       |  7_219_214 |        1_949 |                        2_717 |
| MemoryRegion | 11_380_427 |  205_777_182 |                  204_056_008 |


Heap

|              | addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | --------: | -----------: | ---------------------------: |
| Region       |     9_040 |        8_952 |                        8_952 |
| MemoryRegion |     9_040 |    6_287_252 |                    7_276_152 |

## m = 16
|              |       addBlob() |         removeBlob() | addBlob() after deallocating |
| :----------- | --------------: | -------------------: | ---------------------------: |
| Region       |  7_219_214 (0%) |           1_949 (0%) |                   2_717 (0%) |
| MemoryRegion | 11_380_427 (0%) | 173_198_546 (+0.90%) |         155_355_169 (+2.15%) |


Heap

|              |  addBlob() |        removeBlob() | addBlob() after deallocating |
| :----------- | ---------: | ------------------: | ---------------------------: |
| Region       | 9_040 (0%) |          8_952 (0%) |                   8_952 (0%) |
| MemoryRegion | 9_040 (0%) | 3_732_816 (+16.15%) |          3_890_064 (+22.79%) |

## m = 124

Instructions

|              |  addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | ---------: | -----------: | ---------------------------: |
| Region       |  7_219_214 |        1_949 |                        2_717 |
| MemoryRegion | 11_380_427 |  192_867_554 |                  172_239_061 |


Heap

|              | addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | --------: | -----------: | ---------------------------: |
| Region       |     9_040 |        8_952 |                        8_952 |
| MemoryRegion |     9_040 |    2_815_376 |                    2_533_424 |

## m = 256

Instructions

|              |  addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | ---------: | -----------: | ---------------------------: |
| Region       |  7_219_214 |        1_949 |                        2_717 |
| MemoryRegion | 11_380_427 |  226_831_614 |                  158_827_384 |


Heap

|              | addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | --------: | -----------: | ---------------------------: |
| Region       |     9_040 |        8_952 |                        8_952 |
| MemoryRegion |     9_040 |    2_700_792 |                    2_301_616 |

## m = 512
Instructions

|              |  addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | ---------: | -----------: | ---------------------------: |
| Region       |  7_219_214 |        1_949 |                        2_717 |
| MemoryRegion | 11_380_427 |  291_885_631 |                  201_383_980 |


Heap

|              | addBlob() | removeBlob() | addBlob() after deallocating |
| :----------- | --------: | -----------: | ---------------------------: |
| Region       |     9_040 |        8_952 |                        8_952 |
| MemoryRegion |     9_040 |    2_710_984 |                    2_231_792 |


# most recent (32)

Instructions

|              |  addBlob() | removeBlob() | removeBlob() merge adjacent blocks | addBlob() after deallocating |
| :----------- | ---------: | -----------: | ---------------------------------: | ---------------------------: |
| Region       |  7_691_624 |        1_964 |                              3_154 |                        2_732 |
| MemoryRegion | 12_541_856 |   90_732_175 |                        239_194_300 |                   84_942_663 |


Heap

|              | addBlob() | removeBlob() | removeBlob() merge adjacent blocks | addBlob() after deallocating |
| :----------- | --------: | -----------: | ---------------------------------: | ---------------------------: |
| Region       |     9_140 |        8_952 |                              8_952 |                        8_952 |
| MemoryRegion |     9_140 |  -27_805_472 |                          4_216_796 |                    2_329_012 |