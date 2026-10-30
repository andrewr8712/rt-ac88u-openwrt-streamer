# Changelog

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
