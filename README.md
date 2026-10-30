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
| Measured | 16/44.1–24/192 PCM and DSD64/128/256 via DoP; 0 USB drops |

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
| `packet_steering`, `cron`, `gpio_switch` disabled | not needed here; `packet_steering` otherwise fails at every boot |
| myMPD `loglevel=3`, MPD `log_level "error"` | quieter logs without hiding errors |
| `actimeo=60` on the CIFS mount | far fewer SMB metadata round-trips while browsing |

Then open `http://<ip>:8080` (myMPD) or `http://<ip>/` (LuCI). myMPD needs
**Music directory = `/mnt/music`** set once (Autodetect only works over a Unix
socket); the setting now persists.

### Manual SMB mount (if you skip the script)

```sh
mkdir -p /mnt/music
printf 'username=USER\npassword=PASS\n' > /etc/smbcredentials
chmod 600 /etc/smbcredentials
echo '//10.0.0.216/public /mnt/music cifs credentials=/etc/smbcredentials,vers=3.0,iocharset=utf8,uid=32768,gid=32768,actimeo=60,ro 0 0' >> /etc/fstab
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
- **M.A.L.P.** (Android, MPD native) — MPD listens on all interfaces
  (`bind_to_address "any"`), so point it at the router IP, port **6600**, no
  password. It browses MPD's database directly.
- **BubbleUPnP / Kazoo / mconnect / Hi-Fi Cast** — UPnP control points; they see
  the `upmpdcli` renderer. Without a UPnP media server they cannot browse the
  SMB library (uprcl needs python3, not installed); use MPD-native apps or
  myMPD for local browsing.

MPD listens on all interfaces (there is no firewall in this image). On a trusted
LAN that is fine; to restrict it, set `bind_to_address` to the router's LAN IP.
MPD also supports `password "…@readwrite"` with all clients supplying it.

## Bit-perfect path

`device "hw:0,0"`, `mixer_type "none"`, no resampling (the build has no soxr or
libsamplerate), no PulseAudio. PCM is passed through untouched; DSD uses DoP
(DSD64 → 176.4 kHz, DSD128 → 352.8 kHz, DSD256 → 705.6 kHz — all measured, see
below). Unsupported rates fail rather than being converted. For strict
bit-perfect output keep the DAC at 0 dB / fixed volume.

## Measured performance

Measured over **9 m 49 s** of continuous playback (40 samples at 15 s intervals)
on the RT-AC88U — dual Cortex-A9 @ 1.4 GHz, 512 MB RAM.

| Source | MPD reports | ALSA `hw_params` | CPU avg / max |
|---|---|---|---|
| 16/44.1 FLAC | `44100:16:2` | 44100 Hz | 4.4 % / 6.6 % |
| 24/96 FLAC | `96000:24:2` | 96000 Hz | 5.9 % / 9.1 % |
| 24/192 FLAC | `192000:24:2` | 192000 Hz | 7.7 % / 13.3 % |
| DSD64 | `dsd64:2` | 176400 Hz (DoP) | 7.6 % / 10.6 % |
| DSD128 | `dsd128:2` | 352800 Hz (DoP) | 6.5 % / 9.4 % |
| DSD256 | `dsd256:2` | **705600 Hz (DoP)** | 11.6 % / 12.7 % |

- Overall CPU: **5.85 % average**, **13.3 % peak** (the peaks coincide with
  format transitions, not steady-state decoding)
- **0 USB disconnects**, no xruns or decode errors in `logread`
- Every rate matched the source exactly — no resampling anywhere in the chain
- DSD256 over DoP works; DSD512 would need native DSD

Reproduce:

```sh
printf 'status\nclose\n' | nc 127.0.0.1 6600   # state + audio format
cat /proc/asound/card0/pcm0p/sub0/hw_params     # what ALSA feeds the DAC
dmesg | grep -c 'USB disconnect'                # link stability
```

Raw CPU / memory / storage microbenchmarks (with the benchmark source and raw
output) are in [BENCHMARKS.md](BENCHMARKS.md) and [`bench/`](bench/) — useful as a
baseline when repeating this build on different hardware.

## Known limitations

- **Wi-Fi unusable** (BCM4366) — wired only.
- **DSD over DoP only** — DSD64/128/256 verified; DSD512 would need native DSD
  (not enabled in this build).
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
| M.A.L.P. can't connect | `bind_to_address "any"`; `netstat -lntp \| grep 6600`; phone on the same subnet (no guest VLAN / AP isolation) |
| `exception: No mixer` | Benign — a client tried to change volume with `mixer_type "none"`; use the DAC's knob |
| USB disconnects in `dmesg` | Cable/port — try the USB 3.0 port, direct (no hub) |
| HTTPS redirect | myMPD `ssl` must be `false`; clear browser HSTS |

See `docs/TROUBLESHOOTING.md` for more.

## Rebuild

```sh
make image PROFILE="asus_rt-ac88u" PACKAGES="<list>" FILES="/path/to/ovl"
```

`ovl/` supplies the custom binaries, `init.d/mympd`, and the first-boot
`uci-defaults`. `docs/BUILD.md` documents the cross-build steps for MPD (DSD)
and myMPD.
