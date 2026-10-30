# Porting to other routers and DACs

The **image** in this repository is specific to the ASUS RT-AC88U. The
**workflow**, overlay layout and scripts are reusable. This guide lists what
must change and what can stay.

## 1. Choose a target and profile

Find the device on <https://openwrt.org/toh/start> and note its:

- target/subtarget (e.g. `bcm53xx/generic`)
- profile name (e.g. `asus_rt-ac88u`)
- CPU architecture and toolchain (the SDK/Image Builder must match)
- flash layout and usable overlay size
- Wi-Fi support (many Broadcom routers have no usable AP driver)

Then set those in `build/packages.txt` and the `make image` command:

```sh
make image PROFILE="<profile>" PACKAGES="$(...)" FILES="$PWD/ovl"
```

`build.sh` reads the package list from `build/packages.txt`.

## 2. Adjust the package list

Keep:

- `kmod-sound-core`, `kmod-usb-audio`, `alsa-utils`, `usbutils`
- `mpd-mini` (the custom MPD binary replaces it), `upmpdcli`
- `kmod-fs-cifs`, `cifsmount` (SMB library)
- `libopenssl`, `libpcre2` (myMPD runtime)
- LuCI modules, `uhttpd`

Remove or change:

- Wi-Fi packages (`wpad-*`, `kmod-brcmfmac`, firmware) — only if the target has
  no usable Wi-Fi or you do not need it
- firewall/NAT/DHCP server packages (`firewall4`, `nftables`, `dnsmasq`,
  `odhcpd`, `ppp`) — only if the device is a pure LAN client
- USB-storage/fs packages if you never attach local disks

Do **not** remove `block-mount`/`fstools`; the static `/etc/fstab` still relies
on the mount helpers.

## 3. Toolchain and binaries

The binaries must be rebuilt for the new architecture:

- `mpd` with `-Ddsd=true` and the same output options
- `mympd` with the `-Werror` patch from `patches/`

`build.sh` parameterises this; override the toolchain path in
`build/mpd-cross.txt` and `build/mympd-toolchain.cmake` for non-ARMv7 targets.

The overlay's `init.d/mpd` is copied from the target image (it is the package's
init with `GROUP="audio"`); regenerate it after changing targets.

## 4. DAC and ALSA

The image assumes a class-compliant UAC2 DAC:

- card 0, device 0 (`hw:0,0`)
- no mixer control (`mixer_type "none"`)
- DoP for DSD

On a new device check:

```sh
lsusb
cat /proc/asound/cards
cat /proc/asound/card0/stream0     # formats/rates the DAC advertises
```

If the DAC is not card 0, change `device "hw:X,0"` in `ovl/etc/mpd.conf`.
DSD over DoP needs PCM rates of 176.4, 352.8 or 705.6 kHz. Native DSD needs
DAC-specific quirks and is not enabled here.

USB port choice matters: on this router the rear USB 2.0 port caused `error -71`
re-enumeration; the front USB 3.0 port was stable.

## 5. First boot and network

The image defaults to a **DHCP client**; it does not run a DHCP server. After
flashing, find the lease in your router's client list, then:

```sh
ssh root@<ip>
```

If you have no console, keep a serial adapter or a known static fallback
available. Check `etc/uci-defaults/99-lan-dhcp` before changing the default.

## 6. Persistence

Keep mutable state off `/var` (tmpfs). This image uses:

| Path | Purpose |
|---|---|
| `/etc/mpd` | MPD database, state, playlists |
| `/etc/mympd` | myMPD settings and state |
| `/etc/fstab` | static CIFS mount |

The overlay is the only writable persistent filesystem. Size it before
installing large packages; a 16 MB overlay is enough for this stack.

## 7. SMB library

`post-flash-setup.sh` adds the CIFS entry and credentials. Change
`SMB_SERVER`, `SMB_SHARE`, `SMB_USER`, `SMB_PASS`. The mount uses `actimeo=60`
and `ro`; adjust for read-write libraries.

## 8. Validation checklist

Run on the candidate device:

```sh
./qualify.sh                 # board, ALSA, USB, benchmark summary
printf 'stats\nclose\n' | nc 127.0.0.1 6600
cat /proc/asound/card0/pcm0p/sub0/hw_params
dmesg | grep -c 'USB disconnect'
```

Then play one PCM and one DSD file and confirm the rate in `hw_params` matches
the source. See `BENCHMARKS.md` for the performance baseline and
`docs/TROUBLESHOOTING.md` for failure modes.

## 9. Known constraints

- OpenWrt 24.10.x is the current base; 25.12 changes `opkg` → `apk` and the
  toolchain, and is a separate rebase.
- BCM4366 Wi-Fi is not usable under OpenWrt; this build is wired-only.
- DSD is DoP-only; DSD512 is not supported.
- myMPD Lua scripting and FLAC/id3tag support are disabled in the custom build.
