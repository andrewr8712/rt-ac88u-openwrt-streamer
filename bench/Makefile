# Cross-build the benchmark as a static binary for OpenWrt (musl, ARM).
# Point SDK at an extracted OpenWrt SDK for the target.
SDK ?= /opt/openwrt-sdk
# Toolchain gcc version: 14.3.0 for the 25.12 SDK, 13.3.0 for 24.10.
TCVER ?= 14.3.0
TC  := $(SDK)/staging_dir/toolchain-arm_cortex-a9_gcc-$(TCVER)_musl_eabi/bin
CC  := $(TC)/arm-openwrt-linux-muslgnueabi-gcc

bench: bench.c
	STAGING_DIR=$(SDK)/staging_dir $(CC) -static -O2 -pthread -o $@ $<

clean:
	rm -f bench

.PHONY: clean
