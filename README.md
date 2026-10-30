# Custom OpenWrt image — ASUS RT-AC88U music streamer

Built with the **OpenWrt 24.10.8 Image Builder**, target `bcm53xx/generic`,
profile `asus_rt-ac88u`. Replaces the Volumio box; music lives on a network
PC shared over SMB.

| | |
|---|---|
| Image | `openwrt-24.10.8-bcm53xx-generic-asus_rt-ac88u-squashfs.trx` |
| Size | ~14 MB |
| SHA256 | `532262ce38b0f6b5f0d5fe6d77015778a007ad926a165357e986df7221d5b029` |
| Player | custom `mpd` 0.23.15 — DSD (DSF/DFF) + FLAC/AAC/MP3/OGG, ALSA out |
| Web UI (music) | **myMPD 26.1.1** on port **8080** |
| Web UI (admin) | **LuCI** on port **80** |
| UPnP | `upmpdcli` (DLNA/UPnP AV + OpenHome renderer fronting MPD) |
| Library | **SMB/CIFS client**: `kmod-fs-cifs` + `cifsmount` (mount.cifs) |
| Diagnostics | `alsa-utils`, `usbutils` |

## Packages added
`kmod-sound-core kmod-usb-audio alsa-utils usbutils mpd-mini upmpdcli
kmod-fs-cifs cifsmount libopenssl3 libpcre2`

LuCI (module-level, no firewall/PPP apps):
`luci-base luci-mod-system luci-mod-network luci-mod-status luci-mod-dashboard
luci-theme-bootstrap luci-app-package-manager uhttpd`

## Removed (vs. stock router image)
`firewall4 nftables kmod-nft-offload dnsmasq odhcpd-ipv6only odhcp6c ppp
ppp-mod-pppoe wpad-basic-mbedtls kmod-brcmfmac brcmfmac-firmware-4366b1-pcie
brcmfmac-firmware-4366c0-pcie iwinfo`

Notes:
- `mpd-full` rejected (feed builds it with PulseAudio → BlueZ/Avahi/D-Bus bloat).
- `/usr/bin/mpd` is a **custom DSD-enabled build** overlaid on `mpd-mini`.
- `/usr/bin/mympd` is a **custom build** (assets embedded; Lua/utf8proc/id3tag/FLAC
  support disabled to keep it lean — tag data still comes from MPD).

## Flash it
1. Power off. Hold **Reset**, power on, keep holding until the power LED blinks.
2. PC at static `192.168.1.2 / 255.255.255.0`.
3. Browse `http://192.168.1.1`, **reset NVRAM**, upload the `.trx`
   (or use ASUS Firmware Restoration).
4. Reboot; LAN comes up as a **DHCP client** (below).

## First access — LAN is a DHCP client
No local DHCP server. `/etc/uci-defaults/99-lan-dhcp` sets LAN to DHCP client on
first boot. Plug a **LAN** port into your network, find the lease (hostname
`OpenWrt`), then `ssh root@<ip>`. WAN is also a DHCP client.

Pin a fixed address later:
```sh
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.50'
uci set network.lan.netmask='255.255.255.0'
uci commit network
/etc/init.d/network restart
```

## Mount the SMB music share
```sh
mkdir -p /mnt/music
cat > /etc/smbcredentials <<'EOF'
username=YOURUSER
password=YOURPASS
EOF
chmod 600 /etc/smbcredentials

uci add fstab mount
uci set fstab.@mount[-1].target='/mnt/music'
uci set fstab.@mount[-1].device='//192.168.1.10/Music'
uci set fstab.@mount[-1].fstype='cifs'
uci set fstab.@mount[-1].options='credentials=/etc/smbcredentials,vers=3.0,iocharset=utf8,ro'
uci set fstab.@mount[-1].enabled='1'
uci commit fstab
/etc/init.d/fstab enable
mount -a
```
`mount.cifs` lives at `/usr/sbin/mount.cifs`; plain `mount -t cifs ...` also works.
Adjust the server/share and `vers=` to match the PC (try `3.0`, `3.1.1`, or `2.1`).

## Configure the player
```sh
scp post-flash-setup.sh root@<ip>:/tmp/
ssh root@<ip> sh /tmp/post-flash-setup.sh
```
Writes `/etc/mpd.conf` (music dir `/mnt/music`, ALSA `hw:0,0`, mixer off,
`dop "yes"`), points upmpdcli at local MPD, enables **mpd**, **upmpdcli** and
**mympd**.

Verify hardware:
```sh
lsusb        # Topping
aplay -l     # card 0: DX5 ...
```

## Web UIs
- **myMPD** — `http://<ip>:8080` — library browse, queue, search, playlists,
  album art. Installable as a PWA on Android.
- **LuCI** — `http://<ip>/` — system, network, services, logs, package manager.

## Phone control
- **myMPD PWA** (add to home screen) — same UI as desktop.
- **M.A.L.P.** (Android, MPD-native) — needs `bind_to_address "any"` in
  `/etc/mpd.conf`; then it browses MPD's database directly.
- **BubbleUPnP / Kazoo / mconnect / Hi-Fi Cast** — UPnP control points; they see
  the `upmpdcli` renderer. Note: without a UPnP media server they can't browse
  the SMB library (uprcl needs python3, which isn't installed). Use M.A.L.P. or
  myMPD for local browsing, or add `minidlna` later if you want UPnP browsing.

## Known limitations
- **Wi-Fi dead** (BCM4366) — wired only.
- **DSD is DoP-only** — DSD64/128 fine; DSD256/512 may exceed DoP.
- **Codecs:** FLAC/AAC/MP3/OGG/DSD/PCM; no ALAC/WMA/APE.
- **myMPD Lua scripting disabled** (no liblua in image).
- **Client device**: no firewall/NAT/DHCP/DNS; LuCI has no firewall/PPP apps.

## Download
The flashable image is attached to the [v1.0 release](https://github.com/andrewr8712/rt-ac88u-openwrt-streamer/releases/tag/v1.0):

`openwrt-24.10.8-bcm53xx-generic-asus_rt-ac88u-squashfs.trx` (SHA256 `532262ce38b0f6b5f0d5fe6d77015778a007ad926a165357e986df7221d5b029`).

## Documentation
- [Hardware notes](docs/HARDWARE.md) — router, DAC, Wi-Fi/serial caveats
- [Build notes](docs/BUILD.md) — reproducing the image and the custom binaries
- [Troubleshooting](docs/TROUBLESHOOTING.md) — no IP, DAC, SMB, myMPD, bit-perfect checks
- [Changelog](CHANGELOG.md)

## Rebuild
```sh
make image PROFILE="asus_rt-ac88u" PACKAGES="<list>" FILES="/path/to/ovl"
```
`ovl/` carries `/usr/bin/mpd` (DSD build), `/usr/bin/mympd`, `init.d/mympd`, and
the first-boot uci-defaults scripts.
