# Custom OpenWrt image for the ASUS RT-AC88U

OpenWrt 25.12.6, set up as a wired network music streamer feeding a USB DAC
(Topping DX5 II). Music stays on an SMB share; the library, queue and settings
survive reboots. This image is built for that router and that DAC. For other
hardware, read [Porting](docs/PORTING.md) first.

## Quick start

### 1. Download

[v2.1 release](https://github.com/andrewr8712/rt-ac88u-openwrt-streamer/releases/tag/v2.1)

File: `openwrt-25.12.6-bcm53xx-generic-asus_rt-ac88u-squashfs.trx`
Size: 13,369,344 bytes
SHA256: `2b403fc7eecce470e5a44e06e92589b48149d46d6611390e9599ccb3a69ec628`

v2.1 uses native DSD by default (`dop "no"`); see [DSD](#dsd). Verify the
download with `sha256sum FILE` before flashing.

### 2. Flash

1. Power off, hold **Reset**, power on until the power LED blinks slowly.
2. Put your PC at `192.168.1.2/24` and open `http://192.168.1.1`.
3. Reset NVRAM, upload the `.trx`, or use the ASUS Firmware Restoration tool.
4. Reboot.

#### Upgrade an existing install

On 25.12, `sysupgrade` can ignore `/etc/sysupgrade.conf` and drop the files it
lists. Back up what you cannot regenerate:

```sh
tar czf /tmp/pre-upgrade.tgz /etc /etc/mpd
```

After the reboot, compare `/etc/config`, `/etc/fstab`,
`/root/.ssh/authorized_keys` and `/etc/mpd` with the backup, restore what is
missing, and re-add the keep list to `/etc/sysupgrade.conf`.

### 3. First access

There is no DHCP server in the image. On first boot the LAN bridge is a DHCP
client. Plug a LAN port into your network, find the lease (hostname `OpenWrt`)
in your main router, then set a root password with `passwd`. The WAN port is
also a DHCP client.

To pin an address later:

```sh
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.50'
uci set network.lan.netmask='255.255.255.0'
uci commit network
/etc/init.d/network restart
```

### 4. Point it at your music

`post-flash-setup.sh` reads the SMB settings from the environment, so no
password is stored in the file:

```sh
scp post-flash-setup.sh root@IP_ADDRESS:/tmp/
ssh -t root@IP_ADDRESS \
    SMB_SERVER=192.168.1.10 SMB_SHARE=Music SMB_USER=andrew SMB_PASS='...' \
    sh /tmp/post-flash-setup.sh
```

Replace `IP_ADDRESS` with the router's address. Omit `SMB_PASS` to run the
bring-up without touching `/etc/fstab` or the credentials file.

The script is idempotent and handles the bring-up steps that are easy to miss:

| Step | Why |
|---|---|
| `GROUP="audio"` for MPD + `mpd` added to `audio` | `/dev/snd` is `root:audio 660`; otherwise playback fails |
| MPD DB/state/playlists → `/etc/mpd` | `/var` is tmpfs, so the DB would be lost every boot |
| myMPD workdir → `/etc/mympd` | otherwise music-directory and SSL settings reset every boot |
| myMPD uid 91 (not 89) | 89 collides with `upmpdcli` |
| `ssl=false` in myMPD | avoids forced self-signed HTTPS on :8443 |
| static `/etc/fstab` CIFS entry | UCI `fstab` entries are not mounted by `block mount` for network shares |
| `/etc/rc.local` waits on `/proc/mounts` | `[ -d /mnt/music ]` is true even when unmounted |
| `mpd-dirs` service (S92) | recreates and chowns persistent dirs before MPD starts |
| `packet_steering`, `cron`, `gpio_switch` disabled | not needed here; `packet_steering` otherwise fails at every boot |
| myMPD `loglevel=4`, MPD `log_level "error"` | warnings and errors retained (3 is errors only) |
| `actimeo=60` on the CIFS mount | far fewer SMB metadata round-trips while browsing |

#### Manual SMB mount

If you skip the script:

```sh
mkdir -p /mnt/music
printf 'username=USER\npassword=PASS\n' > /etc/smbcredentials
chmod 600 /etc/smbcredentials
echo '//192.168.1.10/Music /mnt/music cifs credentials=/etc/smbcredentials,vers=3.0,iocharset=utf8,uid=32768,gid=32768,actimeo=60,ro 0 0' >> /etc/fstab
mount -a
```

`uid`/`gid` are those of the `mpd` user (`id -u mpd`). `iocharset=utf8` keeps
non-ASCII album names readable. Try `vers=3.1.1` or `2.1` if the server rejects
`3.0`.

### 5. Open the web UIs

- myMPD: `http://IP_ADDRESS:8080`; library, queue, search, playlists, artwork.
  Installable as a PWA. Plain HTTP; SSL is off by default.
- LuCI: `http://IP_ADDRESS/`; system, network, services, logs, packages.

The script presets myMPD's music directory to `/mnt/music` (Autodetect only
works over a Unix socket); verify it on the myMPD MPD-connection page.

If a browser forces HTTPS, it has a cached redirect or HSTS entry; clear it for
the IP (Chrome: `chrome://net-internals/#hsts`; Firefox: HTTPS-Only exception;
or use a private window).

## DSD

The default output is native DSD (`dop "no"`): MPD opens the Topping's
`DSD_U32_BE` altset (Interface 1, Altset 3), so the DSD bitstream reaches the
DAC without PCM framing. Verified on 2026-11-05:

| Format | MPD reports | ALSA `hw_params` | Carrier |
|---|---|---|---|
| DSD128 | `dsd128:2` | `DSD_U32_BE` | 176400 Hz |
| DSD512 | `dsd512:2` | `DSD_U32_BE` | 705600 Hz (2.0 GB Polly Gibbons test track) |

The streamer handles DSD64/128/256 (DoP baseline) and native DSD128/512. DSD64
and DSD256 use the same native path but were not re-measured after the switch.

DoP is still available with `dop "yes"`; it cannot carry DSD512, which would
need a 1.536 MHz PCM carrier beyond the DAC's 768 kHz input limit.

## Clients

- Plinth: the Android controller this streamer was built with. It talks MPD
  directly and keeps a cached library; see
  [andrewr8712/plinth](https://github.com/andrewr8712/plinth).
- myMPD PWA: add the web UI to your home screen.
- M.A.L.P.: MPD-native Android client. Point it at the router IP, port 6600, no
  password. It browses MPD's database directly.
- BubbleUPnP, Kazoo, mconnect, Hi-Fi Cast: UPnP control points. They see the
  `upmpdcli` renderer. Without a UPnP media server they cannot browse the SMB
  library (uprcl needs python3, not installed); use an MPD-native app or myMPD
  for local browsing.

MPD listens on all interfaces and there is no firewall in this image. On a
trusted LAN that is fine. To restrict it, set `bind_to_address` to the router's
LAN IP. MPD also supports `password "PASSWORD@readwrite"` with every client
supplying it.

## Troubleshooting

| Symptom | Check |
|---|---|
| `Failed to open ... hw:0,0` | `id mpd` must include `audio`; `ls -l /dev/snd`; USB churn in `dmesg` |
| Library empty after reboot | `grep ' /mnt/music ' /proc/mounts`; if missing, `mount -a && /etc/init.d/mpd restart` |
| myMPD settings reset | workdir must be `/etc/mympd` (`grep -- '-w' /etc/init.d/mympd`) |
| MPD won't start | `logread \| grep mpd`, usually `/etc/mpd` permissions |
| M.A.L.P. can't connect | `bind_to_address "any"`; `netstat -lntp \| grep 6600`; phone on the same subnet (no guest VLAN or AP isolation) |
| `exception: No mixer` | Benign: a client tried to change volume with `mixer_type "none"`; use the DAC's knob |
| USB disconnects in `dmesg` | Use the front USB 3.0 port, direct, no hub; the rear USB 2.0 port produced `error -71` |
| HTTPS redirect | myMPD `ssl` must be `false`; clear the browser's HSTS entry |

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more.

## Reference

### Measured performance (DoP baseline)

The table below is the DoP baseline from the 24.10 build, kept for comparison.
The current image defaults to native DSD; see [DSD](#dsd).

Measured over 9 m 49 s of continuous playback (40 samples at 15 s intervals;
24.10.8 baseline, DSD64 re-verified on 25.12.6) on the RT-AC88U (dual Cortex-A9
at 1.4 GHz, 512 MB RAM).

| Source | MPD reports | ALSA `hw_params` | CPU avg / max |
|---|---|---|---|
| 16/44.1 FLAC | `44100:16:2` | 44100 Hz | 4.4 % / 6.6 % |
| 24/96 FLAC | `96000:24:2` | 96000 Hz | 5.9 % / 9.1 % |
| 24/192 FLAC | `192000:24:2` | 192000 Hz | 7.7 % / 13.3 % |
| DSD64 | `dsd64:2` | 176400 Hz (DoP) | 7.6 % / 10.6 % |
| DSD128 | `dsd128:2` | 352800 Hz (DoP) | 6.5 % / 9.4 % |
| DSD256 | `dsd256:2` | 705600 Hz (DoP) | 11.6 % / 12.7 % |

- Overall CPU: 5.85 % average, 13.3 % peak (the peaks coincide with format
  transitions, not steady-state decoding).
- 0 USB disconnects, and no xruns or decode errors in `logread`.
- Every rate matched the source exactly; there is no resampling anywhere in the
  chain.
- DoP baseline: DSD256 over DoP works; DSD512 cannot be carried by DoP.

To reproduce:

```sh
printf 'status\nclose\n' | nc 127.0.0.1 6600   # state + audio format
cat /proc/asound/card0/pcm0p/sub0/hw_params     # what ALSA feeds the DAC
dmesg | grep -c 'USB disconnect'                # link stability
```

Raw CPU, memory and storage numbers are in [BENCHMARKS.md](BENCHMARKS.md) and
[`bench/`](bench/); use them as a baseline when repeating this build on other
hardware.

### Load test

A 62.5-minute load test on 2026-11-05 ran both cores saturated and a 2 GB CIFS
read while the queue played. All 240 samples were in `play`: 0 stalls, 0
pauses or stops, 0 MPD, USB, CIFS or ALSA errors, 16 clean track changes. Peak
CPU 99.8 %, peak temperature 76.6 °C, memory available never below 311 MB. The
report and raw data are in
[docs/STABILITY-2026-11-05.md](docs/STABILITY-2026-11-05.md).

### Tested on

- ASUS RT-AC88U (bcm4709c0, 2× Cortex-A9, 512 MB), OpenWrt 25.12.6.
- Topping DX5 II on the front USB 3.0 port; the rear USB 2.0 port caused
  `error -71`.
- SMB3 share on a separate PC; myMPD, LuCI and M.A.L.P. clients.
- 9 m 49 s continuous playback across PCM and DSD; see
  [BENCHMARKS.md](BENCHMARKS.md).
- 62.5 min under full CPU and CIFS load; see
  [docs/STABILITY-2026-11-05.md](docs/STABILITY-2026-11-05.md).

### What is in the image

The image includes MPD 0.23.16 (DSD-enabled), myMPD 26.1.1, LuCI, upmpdcli
1.8.11 and the SMB/CIFS client. The package list is in
[`build/packages.txt`](build/packages.txt); the installed set (167 packages) is
in the
[manifest](manifests/openwrt-25.12.6-bcm53xx-generic-asus_rt-ac88u.manifest).

Not installed: `firewall4`, `nftables`, `dnsmasq`, `odhcpd`/`odhcp6c`, `ppp`,
and the Wi-Fi stack (`wpad`, `kmod-brcmfmac`, the 4366 firmware, `iwinfo`).
`/usr/bin/mpd` is a custom DSD-enabled build overlaid on `mpd-mini`;
`/usr/bin/mympd` is a custom myMPD build with embedded assets.

### Persistence

| Path | Content | Survives reboot |
|---|---|---|
| `/etc/mpd/tag_cache` | MPD database | Yes (overlay) |
| `/etc/mpd/state`, `/etc/mpd/playlists` | MPD state and playlists | Yes |
| `/etc/mympd/` | myMPD config, state, covers | Yes |
| `/var/cache/mympd` | regenerable caches | No (tmpfs, intentional) |
| `/mnt/music` | SMB mount | remounted at boot |

Boot order: `fstab` attempts the mount, `rc.local` waits for `/proc/mounts` and
runs `mount -a`, then restarts MPD/upmpdcli, and MPD loads the persistent
database without a rescan.

### Bit-perfect path

`device "hw:0,0"`, `mixer_type "none"`, no resampling (the build has no soxr or
libsamplerate) and no PulseAudio. PCM passes through untouched. DSD uses native
DSD by default (`dop "no"`), so the bitstream reaches the DAC without PCM
framing. Unsupported rates fail rather than being converted. For strict
bit-transparent output, keep the DAC at 0 dB or fixed volume.

"Bit-perfect" here means bit-transparent by construction: no resampling, mixing
or volume processing, and the negotiated rate and format were verified at the
DAC. No null-test or bit-error measurement has been performed.

### Security

- No firewall, NAT or DHCP server: the device is a LAN client. Keep it on a
  trusted network.
- MPD listens on port 6600 on all interfaces; anyone on the LAN can control
  playback. Restrict it with `bind_to_address` or an MPD `password` if needed.
- myMPD and LuCI are plain HTTP (8080 and 80). Do not expose them to the
  internet.
- Set a root password (`passwd`) before connecting to a shared network.

### Known limitations

- Wi-Fi is unusable (BCM4366); the device is wired only.
- DSD is native by default; DoP is available with `dop "yes"`.
- Codecs: FLAC, AAC, MP3, OGG, DSD and PCM; no ALAC, WMA or APE.
- myMPD Lua scripting is disabled (no liblua in the image).
- The device is a client only: no firewall, NAT, DHCP or DNS server.

### Support boundary

Provided as-is for this exact router and DAC combination. Other hardware needs
the changes in [docs/PORTING.md](docs/PORTING.md); there is no warranty, so test
before relying on it.

## Development

### Build

The pinned versions, the Image Builder command, the custom MPD and myMPD
builds, and the overlay contents are in [docs/BUILD.md](docs/BUILD.md).
`build.sh` automates them.

### Porting

The image is specific to the RT-AC88U; the workflow and overlay layout are
reusable. [docs/PORTING.md](docs/PORTING.md) lists the target, DAC, network and
persistence changes. Run [`qualify.sh`](qualify.sh) on the candidate device for
a compatibility report.

### Rebuild

```sh
make image PROFILE="asus_rt-ac88u" PACKAGES="<list>" FILES="/path/to/ovl"
```

`ovl/` supplies the custom binaries, `init.d/mympd` and the first-boot
`uci-defaults`.

## License

Original scripts, configuration and documentation are MIT licensed; see
[LICENSE](LICENSE). The image bundles GPL-family components (OpenWrt, MPD,
myMPD, upmpdcli); see [NOTICE](NOTICE) for versions, licenses and sources, and
[`patches/`](patches/) for modifications. If you reuse this work, keep the
license and notice files and link back to this repository.
