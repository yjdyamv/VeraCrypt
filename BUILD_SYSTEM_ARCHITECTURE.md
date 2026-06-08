# VeraCrypt 构建系统架构文档

> 生成日期: 2026-06-08 | VeraCrypt 源码分析

---

## 1. 总体架构

VeraCrypt 使用**三套并行构建系统**，分别服务不同平台。**CMake 不参与编译，仅用于 Linux CPack 打包。**

```
src/Makefile (Unix)          VeraCrypt.sln (Windows)         CMakeLists.txt (仅打包)
     │                              │                               │
  Linux/macOS/FreeBSD        VS 2022 (13 个 .vcxproj)          .deb / .rpm 生成
  OpenBSD/Solaris            + WDK (内核驱动)                  (CPack 配置)
```

---

## 2. 目录结构 (`src/`)

```
src/
├── VeraCrypt.sln                    # VS 2022 解决方案 (13 个项目)
├── Makefile                         # Unix 平台顶层 Makefile (749 行)
│
├── Boot/
│   ├── EFI/                         # 预编译 UEFI 引导程序 (EDK II)
│   └── Windows/                     # 16-bit BIOS 引导 (NMAKE + MSVC 1.5)
│
├── Build/
│   ├── CMakeLists.txt               # CPack 配置 (478 行，仅 DEB/RPM 打包)
│   ├── Include/Makefile.inc         # 共享编译规则 (142 行)
│   ├── build_veracrypt_linux.sh     # Linux 完整构建脚本
│   ├── build_veracrypt_macosx.sh    # macOS 完整构建脚本
│   ├── build_veracrypt_freebsd.sh   # FreeBSD 构建脚本
│   ├── build_veracrypt_openwrt.sh   # OpenWrt 交叉编译
│   ├── build_cmake_deb.sh           # DEB 打包流水线
│   ├── build_cmake_rpm.sh           # RPM 打包流水线
│   ├── build_cmake_opensuse.sh      # openSUSE RPM 打包
│   ├── sign_rpm.sh                  # RPM 签名
│   ├── veracrypt-launchpad-uploader.py
│   ├── Resources/                   # macOS Info.plist, 图标
│   ├── Packaging/                   # Arch PKGBUILD, OpenWrt Makefile.in
│   └── Tools/                       # 可重现构建辅助脚本
│
├── Common/                          # 公共代码 (279 文件, 含 lzma/zlib/libzip)
├── Core/                            # 核心逻辑 (41 文件)
│   └── Unix/                        # Linux/FreeBSD/MacOSX 平台实现
├── Crypto/                          # 密码学实现 (114 文件, 含汇编)
├── Driver/                          # 内核驱动 (15 文件)
│   └── Fuse/Driver.make             # Unix FUSE 用户态驱动
├── Main/                            # 主程序 GUI + CLI (105 文件)
├── Mount/                           # Windows 主程序 (9 文件)
├── Format/                          # 卷创建工具 (7 文件)
├── ExpandVolume/                    # 卷扩容工具 (7 文件)
├── Setup/                           # Windows 安装程序 + Linux/FreeBSD 配置
├── SetupDLL/ FormatDLL/ COMReg/    # Windows 辅助 DLL
├── Platform/                        # OS 抽象层 (61 文件)
│   └── Unix/                        # Unix 平台实现
├── Volume/                          # 卷/加密层 (37 文件)
├── PKCS11/                          # PKCS#11 安全令牌头文件 (4 文件)
├── Signing/                         # Windows 代码签名脚本和证书
└── Resources/                       # 图标、图片
```

---

## 3. Unix 构建系统 (Makefile 体系)

### 3.1 整体架构

顶层 `Makefile` 按顺序构建 5 个子模块，每个子模块生成一个静态库 `.a`：

```
Platform → Volume → Core → Driver/Fuse → Main (链接所有 .a → veracrypt)
```

每个子模块有对应的 `.make` 文件和共享的 `Build/Include/Makefile.inc`。

### 3.2 关键 Make 变量

| 变量 | 说明 |
|------|------|
| `WXSTATIC=1` | 静态链接 wxWidgets |
| `NOGUI=1` | 纯控制台版本，无 GUI 依赖 |
| `WITHFUSE3=1` | 使用 FUSE3 (默认 FUSE2) |
| `WITHFUSET=1` | macOS 使用 FUSE-T |
| `NOSSE2=1` | 禁用 SSE2 |
| `WOLFCRYPT=1` | 使用 wolfCrypt 加密后端 |
| `NOASM=1` | 禁用汇编优化 |
| `INDICATOR=1` | 系统托盘指示器 |
| `VERBOSE=1` | 详细输出 |
| `PKCS11_INC=<path>` | PKCS#11 头文件路径 |

### 3.3 SIMD 多版本编译 (Unix 特有)

**这是 Makefile 系统最复杂的特性。** 同一个 C/C++ 源文件被编译多次，使用不同的 CPU 扩展，输出不同扩展名的目标文件：

| 文件扩展名 | 编译选项 | CPU 特性 |
|-----------|---------|---------|
| `.o` | 默认 (SSE2) | 基准 |
| `.o0` | `-O0` | 无优化 (jitterentropy) |
| `.osse41` | `-mssse3 -msse4.1` | SSE4.1 |
| `.ossse3` | `-mssse3` | SSSE3 |
| `.oshani` | `-mssse3 -msse4.1 -msha` | Intel SHA 扩展 |
| `.oaesni` | `-mssse3 -msse4.1 -maes` | AES-NI |
| `.oavx2` | `-mavx2` | AVX2 |
| `.oarmv8crypto` | `-march=armv8-a+crypto` | ARM 密码学扩展 |

所有变体都链接进同一个静态库 `.a`，运行时通过 `cpu.c` 检测 CPU 特性来动态选择最优实现。

### 3.4 构建目标

```bash
make                    # 编译 veracrypt 二进制
make WXSTATIC=1         # 静态链接 wxWidgets
make NOGUI=1            # 纯控制台版本
make wxbuild            # 从源码编译 wxWidgets 3.2.5
make package            # 生成 .tar.gz + 自解压 .sh 安装程序
make appimage           # 生成 AppImage
make install            # 安装到 DESTDIR
```

### 3.5 可重现构建

- `SOURCE_DATE_EPOCH` 从 git HEAD 或 `Common/Tcdefs.h` 自动推导
- `-ffile-prefix-map` / `-fdebug-prefix-map` 路径归一化
- `-fno-record-gcc-switches` 去除编译器命令行嵌入
- `--build-id=sha1` 确定性链接
- 确定性 `ar`/`ranlib` (D 修饰符)
- 确定性 `tar` (排序、固定 mtime)
- `gzip -n` 无时间戳
- 确定性 `makeself`

---

## 4. Windows 构建系统 (Visual Studio)

### 4.1 VS 解决方案

`src/VeraCrypt.sln` (VS 2022, Format Version 12.00)，包含 13 个项目：

| 项目 | GUID | 输出 |
|------|------|------|
| Crypto | `993245CF` | `Crypto.lib` (静态库) |
| Boot | `8B7F059F` | `BootLoader.com`, `BootSector.bin` |
| Lzma | `B896FE1F` | LZMA 静态库 |
| Zip | `6316EE71` | ZIP 静态库 |
| COMReg | `C8914211` | COM 注册工具 |
| Driver | `B5F6C878` | `veracrypt.sys` (内核驱动) |
| ExpandVolume | `9715FF1D` | `VeraCryptExpander.exe` |
| Format | `9DC1ABE2` | `VeraCrypt Format.exe` |
| Mount | `E4C40F94` | `VeraCrypt.exe` (主程序) |
| Portable | `60698D56` | 便携版安装包 |
| Setup | `DF5F654D` | Windows 安装程序 |
| SetupDLL | `ADD324E2` | 安装辅助 DLL |
| FormatDLL | `ED4D0684` | Format SDK DLL |

### 4.2 构建配置

每个项目的配置为 **4 种配置 × 3 种架构** = 12 种组合：

| 配置 | 架构 |
|------|------|
| Debug | ARM64, Win32, x64 |
| Release | ARM64, Win32, x64 |
| Release_SkipOsDriverReqCheck | ARM64, Win32, x64 |
| ReleaseCustomEFI | ARM64, Win32, x64 |

注意：**Win32 配置名称实际指 x86，但部分项目（如 Crypto）Win32 配置映射到 x64。**

### 4.3 SIMD 处理方式 (Windows 特有)

**与 Unix Makefile 不同**，Windows 不编译同一源文件多次。替代方案：

- **每种 SIMD 变体是独立源文件**：(如 `blake2s_SSE2.c`、`blake2s_SSE41.c`、`blake2s_SSSE3.c`)
- **汇编实现直接编译链接**：(`sha256_avx1_x64.asm`、`sha256_avx2_x64.asm`、`sha256_sse4_x64.asm`)
- **运行时通过 `cpu.c` 做 CPU 检测**选择最快实现
- **ARM64 排除所有 x64 汇编**：通过 `ExcludedFromBuild` 条件实现

### 4.4 三种汇编器工具

| 汇编器 | 用途 | 文件格式 |
|--------|------|---------|
| **NASM** | AES x64 汇编 | `.asm` → win64/win32 |
| **YASM** | Twofish, Camellia, SHA-256/512 | `.S`/`.asm` → win64 (gas 解析器) |
| **MASM** (ml64.exe) | RDRAND/RDSEED 指令 | `.asm` → win64 |

### 4.5 关键预处理宏层级

| 宏 | 使用范围 | 含义 |
|-----|---------|------|
| `TC_WINDOWS_DRIVER` | 仅 Driver | 内核模式代码路径 |
| `TCMOUNT` | 仅 Mount | GUI 主程序 |
| `_LIB` | 仅 Crypto | 静态库构建 |
| `WIN32` | 所有项目 | 始终定义（包括 x64） |
| `ARGON2_NO_THREADS` | Crypto, Driver | 禁用 Argon2 线程 |
| `VC_EFI_CUSTOM_MODE` | Mount (CustomEFI) | 自定义 EFI 模式 |

### 4.6 Driver 的特殊性

Driver **不链接** `Crypto.lib`，而是将 Crypto 源码直接重新编译到 `.sys` 中（使用 `TC_WINDOWS_DRIVER`），因为内核模式不能使用 CRT，需要用 `ExAllocatePoolWithTag` 代替 `malloc`，链接 `ntoskrnl.lib`、`hal.lib`、`fltmgr.lib` 等内核库。

### 4.7 代码签名

`Signing/sign.bat`：SHA-256 EV 代码签名 + WiX Toolset 3.11 生成 MSI。

---

## 5. CMake 打包系统 (仅 Linux)

`src/Build/CMakeLists.txt` (478 行) **仅用于包生成，不涉及编译**：

```
make 编译 → veracrypt 二进制 → build_cmake_deb.sh/rpm.sh → cmake → CPack → .deb/.rpm
```

核心流程：
1. 检测发行版 (Debian/Ubuntu/CentOS/Fedora/openSUSE)
2. 根据发行版版本号设定 FUSE 包名 (如 `libfuse2t64`, `libfuse3-4`)
3. 安装文件 → 调用 CPack → 生成 `.deb` 或 `.rpm`

---

## 6. 各平台支持矩阵

| 特性 | Windows | Linux | macOS | FreeBSD |
|------|---------|-------|-------|---------|
| 构建工具 | MSBuild + WDK | GNU Make + CMake/CPack | GNU Make | GNU Make (gmake) |
| 编译器 | MSVC | GCC | Apple Clang/GCC | Clang |
| 汇编器 | NASM + YASM + MASM | YASM | YASM | YASM |
| wxWidgets | 原生 Win32 API | 源码静态编译 | Homebrew 或源码 | 源码静态编译 |
| 输出包 | .exe, .sys, .msi | .deb, .rpm, .tar.gz, AppImage | .pkg, .dmg | .tar.gz, .sh |
| 架构 | x86, x64, ARM64 | x86, x64, arm64/armv7 | x86_64, arm64 (Universal) | x86, x64 |
| 加密后端 | 内置 | 内置 + wolfCrypt | 内置 | 内置 |
| FUSE | 无 (内核驱动) | FUSE2/FUSE3 | MacFUSE/FUSE-T | FUSE |
| 代码签名 | SHA-256 EV (signtool) | RPM 签名 | codesign + productsign | 无 |

---

## 7. 源码统计

| 类型 | 数量 |
|------|------|
| `.c` | 239 |
| `.cpp` | 143 |
| `.h` | 312 |
| `.S` | 10 |
| `.asm` | 22 |
| **总计** | **726** |

最大模块：Common (279), Crypto (114), Main (105), Platform (61), Core (41).

---

## 8. 特殊构建功能

- **可重现构建**：`SOURCE_DATE_EPOCH`，确定性归档、链接、打包
- **EFI 引导**：预编译 UEFI 二进制由独立仓库 [VeraCrypt-DCS](https://github.com/veracrypt/VeraCrypt-DCS) 构建
- **macOS Universal Binary**：`lipo` 合并 arm64 + x86_64
- **wxWidgets 静态最小化**：大量禁用不必要特性以减小体积
- **PKCS#11** 智能卡/安全令牌支持
- **wolfCrypt** 替代加密后端
- **AppImage** 自动下载 `appimagetool` 并打包
