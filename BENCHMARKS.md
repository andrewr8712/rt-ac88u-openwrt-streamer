# Raw performance baseline — ASUS RT-AC88U

Reference numbers for comparing this build against the same setup on other
routers. Measured on the live device, with the benchmark source and raw output
in [`bench/`](bench/).

> These are **microbenchmarks**, not scores from sysbench/CoreMark. Compare only
> like-for-like: same binary, same flags, same kernel/arch class.

## Device under test

| | |
|---|---|
| Board | ASUS RT-AC88U (`bcm53xx`, `bcm4709c0`) |
| CPU | 2× ARM Cortex-A9 @ 1.4 GHz (ARMv7, no cpufreq scaling) |
| BogoMIPS | 1400.00 per core |
| RAM | 509,252 kB usable (~512 MB DDR3) |
| Storage | 128 MB NAND, UBIFS overlay (`noatime`) |
| OS | OpenWrt 24.10.8, Linux 6.6.144 |
| Idle CPU temp | ~72 °C (`cpu-thermal`) |
| Library | SMB3 share mounted with `actimeo=60`, read-only |

Idle load during the run: myMPD + upmpdcli + MPD running, no playback.

## CPU

Dependent-chain integer multiply-add and double multiply-add, 300 M iterations
per thread. `Mops/s` = millions of dependent operations per second.

| Test | Threads | Mops/s |
|---|---:|---:|
| Integer (64-bit MAC chain) | 1 | **99.90** |
| Integer (64-bit MAC chain) | 2 | **199.78** |
| Double (dependent MAC) | 1 | **15.54** |
| Double (dependent MAC) | 2 | **31.00** |

Scaling is essentially linear (2.00×), as expected for two identical A9 cores.
The low FP number is normal: it is a latency-bound dependent chain (FP multiply
latency), not a throughput test.

## Memory

64 MB buffer, 10 passes. `GB/s` = 10⁹ bytes/s.

| Test | GB/s |
|---|---:|
| Sequential read | **0.43** |
| Sequential write | **1.84** |
| `memcpy` (64 MB→64 MB) | **0.36** |

Pointer-chase latency (random permutation, 5 M accesses):

| Working set | Latency |
|---|---:|
| 4 KB | 6.63 ns |
| 64 KB | 18.93 ns |
| 1 MB | 180.59 ns |
| 8 MB | 216.79 ns |
| 32 MB | 276.94 ns |

Interpretation:

- 4 KB fits L1; 64 KB still mostly L2 (256 KB L2 per core) — hence the jump at 1 MB.
- **Read bandwidth is far below write bandwidth.** The Cortex-A9 has no hardware
  prefetcher and limited outstanding loads, so a single core streaming from DDR
  is latency/MLP-limited. Writes are buffered and retire faster. `memcpy` is
  read-limited, so it tracks the read number.
- Multi-core aggregate read bandwidth would be higher; this baseline is
  single-core unless stated.

## Storage and I/O

1 MB blocks, `fsync` on write, `posix_fadvise(DONTNEED)` on read.

| Target | Write MB/s | Read MB/s | Notes |
|---|---:|---:|---|
| `/tmp` (tmpfs, 128 MB) | **307.4** | **396.2** | RAM ceiling, not storage |
| `/etc` (UBIFS overlay, 32 MB) | **51.4** | **88.3** | NAND + ECC, small file |
| `/mnt/music` (CIFS, cold read) | — | **13.0** | server-dependent¹ |

¹ The SMB number reflects the **server, its disk and the network path**, not the
router's CPU. It is included to show the end-to-end library path; do not use it
to compare routers unless both use the same server and share.

Thermal: 72.7 °C before, 73.8 °C after the run.

## Raw output

```
kernel,6.6.144
machine,armv7l
cpu_model,ARMv7 Processor rev 0 (v7l)
bogomips,1400.00
mem_total_kb,509252
temp_mc,72724
cpu_int_1t_mops,99.90
cpu_fp_1t_mops,15.54
cpu_int_2t_mops,199.78
cpu_fp_2t_mops,31.00
membw_read_gbs,0.43
membw_write_gbs,1.84
membw_copy_gbs,0.36
memlat_4k_ns,6.63
memlat_64k_ns,18.93
memlat_1024k_ns,180.59
memlat_8192k_ns,216.79
memlat_32768k_ns,276.94
iowrite_mbs,307.43
ioread_mbs,396.20
iowrite_mbs,51.38
ioread_mbs,88.28
cifs_file,/mnt/music/…/07 Fool's Overture.flac
ioread_mbs,13.03
temp_after_mc,73836
```

(The two `iowrite`/`ioread` pairs are tmpfs then UBIFS, in that order.)

## Reproduce

```sh
# 1. build a static binary for your target
cd bench
make SDK=/path/to/openwrt-sdk            # arm_cortex-a9 + musl by default
# for another target, override TC/CC in bench/Makefile

# 2. copy and run
scp bench root@<router>:/tmp/
ssh root@<router>

/tmp/bench cpu 1
/tmp/bench cpu 2
/tmp/bench membw 64
/tmp/bench memlat
/tmp/bench iowrite /tmp/bench.bin 128 && /tmp/bench ioread /tmp/bench.bin
/tmp/bench iowrite /etc/bench.bin 32 && /tmp/bench ioread /etc/bench.bin
sync; echo 3 > /proc/sys/vm/drop_caches
/tmp/bench ioread "$(ls -S /mnt/music/*/*.flac | head -1)"
```

## Using this as a comparison baseline

- Use the **same binary** (same `-O2`, same source), same block sizes, same
  buffer sizes. Different flags change CPU numbers by tens of percent.
- Run from an **idle** system; stop playback first.
- Note the **kernel version** — scheduler/ARM patches affect FP and memory.
- Record **RAM size** and whether the buffer fits in lowmem; very small routers
  may swap or OOM at 64 MB, so drop to `membw 16` and note it.
- Compare **within the same class** (ARMv7 vs ARMv8, NAND vs eMMC). The absolute
  numbers are not comparable across architectures.
- Single run only; treat differences under ~5 % as noise.
