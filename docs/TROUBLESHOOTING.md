# Troubleshooting

## No IP address after flashing

The image has **no DHCP server**. `/etc/uci-defaults/99-lan-dhcp` sets the LAN
bridge to a DHCP **client** on first boot, so the device expects your router to
hand it an address.

- Plug a **LAN** port into your main network; find the lease (hostname
  `OpenWrt`) in the main router.
- The **WAN** port is also a DHCP client.
- No DHCP server on your network? Use the serial console (115200 8N1, 3.3 V) and
  set a static address:
  ```sh
  uci set network.lan.proto='static'
  uci set network.lan.ipaddr='192.168.1.50'
  uci set network.lan.netmask='255.255.255.0'
  uci commit network
  /etc/init.d/network restart
  ```

## MPD cannot open the DAC

```sh
lsusb            # Topping should be listed
aplay -l         # card 0: DX5 ...
cat /proc/asound/cards
```

- Device must be `hw:0,0` in `/etc/mpd.conf` (no `plughw`, no `default`).
- If the DAC appears as card 1, adjust the device.
- "Failed to open audio device" with a sample-rate error is expected when the
  DAC does not support that rate: this MPD build has **no resampling** support,
  by design (bit-perfect). Supported rates on the DX5 II are broad (44.1–768 kHz).

## DSD files are silent or converted

- `dop "yes"` must be present in the `audio_output` block, and `mixer_type`
  must be `"none"`.
- DoP needs the DAC to accept 176.4 kHz (DSD64) or 352.8 kHz (DSD128) PCM.
- DSD256/512 likely exceed DoP; native DSD is not enabled in this build.
- MPD logs: `logread | grep -i mpd`.

## SMB share will not mount

```sh
mount -t cifs //192.168.1.10/Music /mnt/music \
  -o credentials=/etc/smbcredentials,vers=3.0,iocharset=utf8,ro
dmesg | tail -20        # kernel cifs errors
```

- `mount.cifs` is at `/usr/sbin/mount.cifs` (package `cifsmount`).
- Try `vers=3.1.1`, `3.0`, `2.1` or `1.0` — servers differ.
- `/etc/smbcredentials` must be mode `600`.
- The server share name is case-sensitive in the device path.
- Kernel module: `lsmod | grep cifs`; load with `modprobe cifs`.

## myMPD does not start

```sh
logread | grep -i mympd
ls -ld /var/lib/mympd /var/cache/mympd
grep '^mympd:' /etc/passwd /etc/group
```

- The `mympd` user is created by `/etc/uci-defaults/98-mympd-user` on first
  boot. If missing, add it and restart.
- Web UI: `http://<ip>:8080`.
- MPD must be running: `pgrep mpd`, `nc -z 127.0.0.1 6600`.

## LuCI does not load

```sh
/etc/init.d/uhttpd status
/etc/init.d/rpcd status
netstat -lntp | grep ':80'
```

LuCI is on port **80**. If another service took the port, change
`/etc/config/uhttpd`.

## Bit-perfect checklist

- `device "hw:0,0"` (not `default`/`plughw`).
- `mixer_type "none"`.
- No `format`, `samplerate_converter` or ALSA plugins in the chain.
- DAC volume at 0 dB / fixed.
- DoP only for DSD.
