#!/usr/bin/env bash

set -e
set -o pipefail

git submodule update --init --recursive

cwd=`pwd`

if ! [ -d riscv64-unknown-linux-gnu -a -x riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-gcc ]; then
	echo "Build RISC-V toolchain"
	pushd riscv-gnu-toolchain
	./configure --prefix=$cwd/riscv64-unknown-linux-gnu --with-arch=rv64gc --with-abi=lp64d
	make linux -j `nproc`
	popd
else
	echo "RISC-V toolchain has been built."
fi

export PATH=$cwd/riscv64-unknown-linux-gnu/bin:$PATH

toolchain=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-

echo "Build boot0"
pushd sun20i_d1_spl
make CROSS_COMPILE=$toolchain p=sun20iw1p1 mmc
popd

echo "Build OpenSBI"
pushd opensbi
make CROSS_COMPILE=$toolchain PLATFORM=generic FW_PIC=y FW_OPTIONS=0x2
popd

echo "Build U-Boot"
pushd u-boot
make CROSS_COMPILE=$toolchain nezha_defconfig
make -j16 ARCH=riscv CROSS_COMPILE=$toolchain all
popd

echo "Generate u-boot table of contents"
./u-boot/tools/mkimage -T sunxi_toc1 -d nezha_toc1.cfg u-boot.toc1

echo "Build Linux kernel"
pushd linux
make ARCH=riscv CROSS_COMPILE=$toolchain defconfig
make -j16 ARCH=riscv CROSS_COMPILE=$toolchain
pushd

echo "Generate u-boot script"
./u-boot/tools/mkimage -T script -O linux -d uboot-bootscr.txt  boot.scr

echo "Successfully built all repos"
