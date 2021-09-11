龙芯 NSCSCC(soc_top) 板级支持包


---

## 1. 简介

适配龙芯 NSCSCC 比赛提供的 SOC_RUN_OS 资源包

| 硬件 | 描述 |
| -- | -- |
|CPU| Your awesome CPU |
|主频| 33MHz |
|DDR3| 1GB |
|Flash| 128MB NandFlash、1MB SpiFlash |

## 2. 驱动支持情况及计划

| 驱动 | 支持情况  |  备注  |
| ------ | ----  | :------:  |
| UART | 支持 |  |
| GPIO | 不支持 |  |
| NAND | 不支持 |  |
| DMFE | 不支持 |  |

## 3. 工具链

`RT-Thread`官方使用的`MIPS SDE`工具链过于陈旧且缺乏部分编译功能（如：`-mno-branch-likely`）等，如果没有实现`Branch Likely`功能，需要自己编译新版本`GCC`

编译过程可以参考：[Gist](https://gist.github.com/panpaul/0e34fde8bbd5155b33fe37e517b916fb)
