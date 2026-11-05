# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); each version is dated
and links to its diff or release.

## [v2.1] - 2026-11-05

Native DSD is the default output.

### Added

- Native DSD: MPD opens the DAC's `DSD_U32_BE` altset (Interface 1, Altset 3).
  Verified at DSD128 (176.4 kHz carrier) and DSD512 (705.6 kHz).
- README native-DSD tests.

### Changed

- `dop "no"` is the default; a fresh install uses native DSD. DoP remains
  available with `dop "yes"` and cannot carry DSD512.
- An existing install keeps its `/etc/mpd.conf`; change `dop` by hand to switch.

## [v2.0] - 2026-10-31

Rebased onto OpenWrt 25.12.6.

Breaking: the package manager is now `apk` instead of `opkg`, and the kernel
moves from 6.6 to 6.12. A v1.x `opkg` workflow does not carry over. Upgrading an
existing install needs `sysupgrade`; see *Upgrade an existing install* in the
[README](README.md).

### Added

- `/mnt/music` pre-created in the overlay, so the mount point exists before the
  first `fstab` attempt.

### Changed

- Base moved to OpenWrt 25.12.6: kernel 6.12, gcc 14.3.0, `apk`.
- MPD 0.23.16 built with `-Ddsd=true`.
- myMPD 26.1.1 rebuilt against the 25.12 staging tree (no RPATH, no build paths).
- Image produced with the 25.12 Image Builder plus the custom overlay, bypassing
  the buildroot `mac80211` Kconfig failure.

### Fixed

- DSD64 DoP re-verified on hardware after the rebase.
- Library and myMPD state restored after `sysupgrade` ignored the
  `/etc/sysupgrade.conf` preserve list (credentials, `fstab`, SSH keys and the
  MPD database were missing); the keep list was re-added.

## [v1.2] - 2026-10-30

Configuration is now baked into the image; the setup script handles SMB only.

### Added

- `mpd.conf`, `rc.local`, audio-group init and myMPD first-boot settings in the
  overlay.
- `verify.sh` for binary hygiene, privacy and documentation consistency.

### Changed

- `post-flash-setup.sh` reduced to credentials, mount entry and verification.

### Fixed

- `bench.c`: per-thread CPU results (removes a data race) and a local accumulator
  in the latency loop.

## [v1.1] - 2026-10-30

Privacy and hardening release.

### Added

- `BENCHMARKS.md` and the `bench/` sources.
- Front USB 3.0 documented as the stable port (rear USB 2.0 gave `error -71`).

### Changed

- `mpd` and `mympd` rebuilt with sanitised paths; myMPD RPATH removed.
- myMPD uid 91 and `/etc/mympd` baked into the overlay.
- myMPD `loglevel` 4 (warn); MPD `log_level "error"`.
- Docs reconciled: DSD64/128/256, overlay size, troubleshooting paths, USB notes.

### Removed

- Session logs removed from the entire git history.

### Security

- Personal identifiers scrubbed from scripts, docs and benchmark output.

## [v1.0] - 2026-10-30

First public image for the ASUS RT-AC88U as a network music streamer.

### Added

- OpenWrt 24.10.8, target `bcm53xx/generic`, profile `asus_rt-ac88u`.
- Custom MPD 0.23.15 built with `-Ddsd=true` (DSF/DFF, DoP output).
- upmpdcli 1.8.11 UPnP/DLNA + OpenHome renderer.
- myMPD 26.1.1 web UI on port 8080 (custom build, embedded assets).
- LuCI admin UI on port 80 (module-level, no firewall/PPP apps).
- SMB/CIFS client (`kmod-fs-cifs`, `cifsmount`).
- Bit-perfect PCM path to `hw:0,0`, no resampling or volume processing.
- LAN defaults to a DHCP client on first boot.

### Removed

- `firewall4`/`nftables`, `dnsmasq`, `odhcpd`/`odhcp6c`, `ppp`, Wi-Fi stack.

Known limitations at this release: no Wi-Fi (BCM4366), DoP-only DSD, no
ALAC/WMA/APE, myMPD Lua scripting disabled, UPnP library browsing needs an added
media server.

[v2.1]: https://github.com/andrewr8712/rt-ac88u-openwrt-streamer/releases/tag/v2.1
[v2.0]: https://github.com/andrewr8712/rt-ac88u-openwrt-streamer/compare/v1.2...v2.0
[v1.2]: https://github.com/andrewr8712/rt-ac88u-openwrt-streamer/compare/v1.1...v1.2
[v1.1]: https://github.com/andrewr8712/rt-ac88u-openwrt-streamer/compare/v1.0...v1.1
[v1.0]: https://github.com/andrewr8712/rt-ac88u-openwrt-streamer/releases/tag/v1.0
