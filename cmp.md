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
