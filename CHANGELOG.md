# Changelog

## v2.0 — 2026-10-31

Rebased on OpenWrt 25.12.6.

- Kernel 6.12, gcc 14.3.0, `apk` package manager
- MPD 0.23.16 built with `-Ddsd=true`
- myMPD 26.1.1 rebuilt against the 25.12 staging tree
- Image built via the 25.12 Image Builder with the custom overlay
- DSD64 DoP re-verified on hardware; library and myMPD state restored
- `/mnt/music` pre-created in the overlay

## v1.2 — 2026-10-30

Configuration is now baked into the image; the setup script only handles SMB.

- `mpd.conf`, `rc.local`, audio-group init and myMPD first-boot settings in the overlay
- `post-flash-setup.sh` reduced to credentials, mount entry and verification
- `bench.c`: per-thread CPU results (no data race), local accumulator in latency loop
- Added `verify.sh` for binary hygiene, privacy and documentation consistency

## v1.1 — 2026-10-30

Privacy and hardening release.

- Removed session logs from the entire git history
- Scrubbed personal identifiers from scripts, docs and benchmark output
- Rebuilt `mpd` and `mympd` with sanitised paths; removed myMPD RPATH
- Baked myMPD uid 91 and `/etc/mympd` into the overlay
- myMPD loglevel 4 (warn); MPD `log_level "error"`
- Documented the front USB 3.0 port as the stable one (rear USB 2.0 gave `error -71`)
- Reconciled docs: DSD64/128/256, overlay size, troubleshooting paths, USB notes
- Added `BENCHMARKS.md` and `bench/` sources

## v1.0 — 2026-10-30

First public image for the ASUS RT-AC88U as a network music streamer.

- OpenWrt 24.10.8, target `bcm53xx/generic`, profile `asus_rt-ac88u`
- Custom MPD 0.23.15 built with `-Ddsd=true` (DSF/DFF, DoP output)
- upmpdcli 1.8.11 UPnP/DLNA + OpenHome renderer
- myMPD 26.1.1 web UI on port 8080 (custom build, embedded assets)
- LuCI admin UI on port 80 (module-level, no firewall/PPP apps)
- SMB/CIFS client (`kmod-fs-cifs`, `cifsmount`)
- LAN defaults to a DHCP client on first boot
- Removed: firewall4/nftables, dnsmasq, odhcpd/odhcp6c, ppp, Wi-Fi stack
- Bit-perfect PCM path to `hw:0,0`, no resampling or volume processing

Known limitations: no Wi-Fi (BCM4366), DoP-only DSD, no ALAC/WMA/APE, myMPD Lua
scripting disabled, UPnP library browsing needs an added media server.
