# Eclipse for S-Link SoCs

从官方 Eclipse IDE for Embedded C/C++ Developers 生成 Eclipse for S-Link。

1. 基线从NucleiStudio修改为Eclipse IDE for Embedded C/C++ Developers, 内置JRE
2. 使用S-Link github发布版本的OpenOCD for S-Link
3. 使用xpack-dev-tools github发布版本的windows-build-tools和GCC toolchain
4. 项目不内置phnx-sdk, 构件时从phnx-sdk github下载
