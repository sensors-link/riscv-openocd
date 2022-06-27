# openocd for S-Link SoCs

从官方 riscv/riscv-openocd 生成 openocd for S-Link。

1. 基线为riscv/riscv-openocd 1ba1b87
2. 增加S-Link SoCs支持
3. 删除不需要的target/flash drivers/rtos，减小发布包
