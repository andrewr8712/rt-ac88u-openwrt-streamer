# Custom OpenWrt image — ASUS RT-AC88U music streamer

OpenWrt 24.10.8 for the **ASUS RT-AC88U**, repurposed as a wired network music
streamer feeding a USB DAC (Topping DX5 II). Music lives on an SMB share; state
survives reboots.

| | |
|---|---|
| Image | `openwrt-24.10.8-bcm53xx-generic-asus_rt-ac88u-squashfs.trx` |
| Size | ~14 MB |
| Player | custom `mpd` 0.23.15 — DSD (DSF/DFF) + FLAC/AAC/MP3/OGG, ALSA `hw:0,0` |
| Music UI | **myMPD** — `http://<ip>:8080` |
| Admin UI | **LuCI** — `http://<ip>/` |
| UPnP | `upmpdcli` (DLNA/UPnP AV + OpenHome renderer) |
| Library | SMB/CIFS client (`kmod-fs-cifs` + `cifsmount`) |
| Persistence | MPD DB in `/etc/mpd`, myMPD state in `/etc/mympd` (overlay, not tmpfs) |

## What is included

`kmod-sound-core kmod-usb-audio alsa-utils usbutils mpd-mini upmpdcli
kmod-fs-cifs cifsmount libopenssl3 libpcre2`

LuCI (modules, without the firewall/PPP apps): `luci-base luci-mod-system
luci-mod-network luci-mod-status luci-mod-dashboard luci-theme-bootstrap
luci-app-package-manager uhttpd`

Not installed: `firewall4`, `nftables`, `dnsmasq`, `odhcpd/odhcp6c`, `ppp`,
Wi‑Fi stack (`wpad`, `kmod-brcmfmac`, 4366 firmware, `iwinfo`).

`/usr/bin/mpd` is a custom **DSD-enabled** build overlaid on `mpd-mini`;
`/usr/bin/mympd` is a custom myMPD build (assets embedded).

## Flash

1. Power off, hold **Reset**, power on until the power LED blinks slowly.
2. PC at `192.168.1.2/24`; open `http://192.168.1.1`.
3. Reset NVRAM, upload the `.trx` (or use ASUS Firmware Restoration).
4. Reboot.

## First access

There is **no DHCP server** in the image. On first boot the LAN bridge is a
**DHCP client**; plug a LAN port into your network and find the lease (hostname
`OpenWrt`) in your main router. The WAN port is also a DHCP client.

To pin an address later:

```sh
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.50'
uci set network.lan.netmask='255.255.255.0'
uci commit network
/etc/init.d/network restart
```

Set a root password immediately: `passwd`.

## Configure everything

Edit the SMB settings at the top of `post-flash-setup.sh` (`SMB_SERVER`,
`SMB_SHARE`, `SMB_USER`, `SMB_PASS`), then:

```sh
scp post-flash-setup.sh root@<ip>:/tmp/
ssh root@<ip> sh /tmp/post-flash-setup.sh
```

The script is idempotent and performs the bring-up steps that are easy to miss:

| Step | Why |
|---|---|
| `GROUP="audio"` for MPD + `mpd` added to `audio` | `/dev/snd` is `root:audio 660`; otherwise playback fails |
| MPD DB/state/playlists → `/etc/mpd` | `/var` is tmpfs — otherwise the DB is lost every boot |
| myMPD workdir → `/etc/mympd` | otherwise music-directory/SSL settings reset every boot |
| myMPD uid 91 (not 89) | 89 collides with `upmpdcli` |
| `ssl=false` in myMPD | avoids forced self-signed HTTPS on :8443 |
| static `/etc/fstab` CIFS entry | UCI `fstab` entries are not mounted by `block mount` for network shares |
| `/etc/rc.local` waits on `/proc/mounts` | `[ -d /mnt/music ]` is true even when unmounted |
| `mpd-dirs` service (S92) | recreates/chowns persistent dirs before MPD starts |

Then open `http://<ip>:8080` (myMPD) or `http://<ip>/` (LuCI). myMPD needs
**Music directory = `/mnt/music`** set once (Autodetect only works over a Unix
socket); the setting now persists.

### Manual SMB mount (if you skip the script)

```sh
mkdir -p /mnt/music
printf 'username=USER\npassword=PASS\n' > /etc/smbcredentials
chmod 600 /etc/smbcredentials
echo '//10.0.0.216/public /mnt/music cifs credentials=/etc/smbcredentials,vers=3.0,iocharset=utf8,uid=32768,gid=32768,ro 0 0' >> /etc/fstab
mount -a
```

`uid`/`gid` are those of the `mpd` user (`id -u mpd`). `iocharset=utf8` keeps
non-ASCII album names readable. Try `vers=3.1.1` or `2.1` if the server rejects
`3.0`.

## Persistence model

| Path | Content | Survives reboot |
|---|---|---|
| `/etc/mpd/tag_cache` | MPD database | ✅ (overlay) |
| `/etc/mpd/state`, `/etc/mpd/playlists` | MPD state/playlists | ✅ |
| `/etc/mympd/` | myMPD config, state, covers | ✅ |
| `/var/cache/mympd` | regenerable caches | ❌ (tmpfs, intentional) |
| `/mnt/music` | SMB mount | remounted at boot |

Boot order: `fstab` attempts the mount → `rc.local` waits for `/proc/mounts`,
runs `mount -a`, restarts MPD/upmpdcli → MPD loads the persistent DB (no rescan).

## Web UIs

- **myMPD** — `http://<ip>:8080`; library, queue, search, playlists, artwork.
  Installable as a PWA. Serves plain HTTP; SSL is disabled by default.
- **LuCI** — `http://<ip>/`; system, network, services, logs, packages.

If a browser forces HTTPS, it has cached an old redirect or HSTS entry:
clear it for the IP (Chrome: `chrome://net-internals/#hsts`; Firefox:
HTTPS-Only exception; or test in a private window).

## Phone control

- **myMPD PWA** — add to home screen.
- **M.A.L.P.** (Android, MPD native) — set `bind_to_address "any"` in
  `/etc/mpd.conf` first; it browses MPD directly.
- **BubbleUPnP / Kazoo / mconnect / Hi-Fi Cast** — UPnP control points; they see
  the `upmpdcli` renderer. Without a UPnP media server they cannot browse the
  SMB library (uprcl needs python3, not installed); use MPD-native apps or
  myMPD for local browsing.

## Bit-perfect path

`device "hw:0,0"`, `mixer_type "none"`, no resampling (the build has no soxr or
libsamplerate), no PulseAudio. PCM is passed through untouched; DSD uses DoP
(DSD64 → 176.4 kHz, DSD128 → 352.8 kHz, visible in `hw_params`). Unsupported
rates fail rather than being converted. For strict bit-perfect output keep the
DAC at 0 dB / fixed volume.

## Known limitations

- **Wi-Fi unusable** (BCM4366) — wired only.
- **DSD DoP only** — DSD256/512 need native DSD, not enabled.
- **Codecs:** FLAC/AAC/MP3/OGG/DSD/PCM; no ALAC/WMA/APE.
- **myMPD Lua scripting disabled** (no liblua in the image).
- **Client device:** no firewall/NAT/DHCP/DNS.

## Troubleshooting

| Symptom | Check |
|---|---|
| `Failed to open ... hw:0,0` | `id mpd` must include `audio`; `ls -l /dev/snd`; USB churn in `dmesg` |
| Library empty after reboot | `grep ' /mnt/music ' /proc/mounts`; if missing `mount -a && /etc/init.d/mpd restart` |
| myMPD settings reset | workdir must be `/etc/mympd` (`grep -- '-w' /etc/init.d/mympd`) |
| MPD won't start | `logread \| grep mpd` — usually `/etc/mpd` permissions |
| HTTPS redirect | myMPD `ssl` must be `false`; clear browser HSTS |

See `docs/TROUBLESHOOTING.md` for more.

## Rebuild

```sh
make image PROFILE="asus_rt-ac88u" PACKAGES="<list>" FILES="/path/to/ovl"
```

`ovl/` supplies the custom binaries, `init.d/mympd`, and the first-boot
`uci-defaults`. `docs/BUILD.md` documents the cross-build steps for MPD (DSD)
and myMPD.
