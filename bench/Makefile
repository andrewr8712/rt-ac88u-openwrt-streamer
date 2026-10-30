# Cross-build the benchmark as a static binary for OpenWrt (musl, ARM).
# Point SDK at an extracted OpenWrt SDK for the target.
SDK ?= /opt/openwrt-sdk
TC  := $(SDK)/staging_dir/toolchain-arm_cortex-a9_gcc-13.3.0_musl_eabi/bin
CC  := $(TC)/arm-openwrt-linux-muslgnueabi-gcc

bench: bench.c
	STAGING_DIR=$(SDK)/staging_dir $(CC) -static -O2 -pthread -o $@ $<

clean:
	rm -f bench

.PHONY: clean
