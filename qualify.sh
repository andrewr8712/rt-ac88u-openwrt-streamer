#!/bin/sh
# qualify.sh - print a compatibility report for a candidate OpenWrt streamer.
#
# Run on the device:
#   ./qualify.sh
#   BENCH=/tmp/bench ./qualify.sh      # also run the benchmark if present
#
# Output is Markdown, suitable for pasting into a porting issue.

BENCH=${BENCH:-}
have() { command -v "$1" >/dev/null 2>&1; }

echo "# Streamer qualification"
echo

. /etc/openwrt_release 2>/dev/null || true
echo "| Item | Value |"
echo "|---|---|"
echo "| Model | $(cat /tmp/sysinfo/model 2>/dev/null || echo unknown) |"
echo "| Target | ${DISTRIB_TARGET:-unknown} |"
echo "| Release | ${DISTRIB_RELEASE:-unknown} |"
echo "| Kernel | $(uname -r) |"
echo "| Machine | $(uname -m) |"
echo "| Cores | $(grep -c '^processor' /proc/cpuinfo 2>/dev/null) |"
echo "| CPU | $(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //') |"
echo "| RAM (kB) | $(awk '/MemTotal/{print $2}' /proc/meminfo) |"
echo "| Overlay | $(df -h /overlay 2>/dev/null | awk 'NR==2{print $2" total, "$4" free"}') |"
echo

echo "## USB"
if have lsusb; then
	lsusb 2>/dev/null | sed 's/^/    /'
else
	echo "    lsusb not installed"
fi
echo

echo "## ALSA"
if [ -r /proc/asound/cards ]; then
	sed 's/^/    /' /proc/asound/cards
else
	echo "    no /proc/asound/cards"
fi
for f in /proc/asound/card*/stream0; do
	[ -f "$f" ] || continue
	echo
	echo "### $f"
	sed 's/^/    /' "$f"
done
echo

echo "## Kernel audio modules"
lsmod 2>/dev/null | grep -E 'snd_usb_audio|snd_pcm|usb_storage' | sed 's/^/    /' || true
echo

echo "## USB stability"
echo "    disconnects in dmesg: $(dmesg 2>/dev/null | grep -c 'USB disconnect')"
echo

if [ -n "$BENCH" ] && [ -x "$BENCH" ]; then
	echo "## Benchmark"
	echo '```'
	"$BENCH" cpu 1
	"$BENCH" cpu 2
	"$BENCH" membw 64
	"$BENCH" memlat
	echo '```'
else
	echo "## Benchmark"
	echo "    set BENCH=/path/to/bench to include CPU/memory results"
fi
