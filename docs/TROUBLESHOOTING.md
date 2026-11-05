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
- "Failed to open audio device" with a sample-rate error is expected when the DAC
  does not support that rate: this MPD build has **no resampling** support by
  design, so unsupported formats fail rather than being converted. The DX5 II
  accepts 44.1–768 kHz PCM.

## The DAC keeps disconnecting

`dmesg` shows `error -71`, repeated disconnect/re-enumeration, or "attempt power
cycle". That is a physical-layer symptom, not an ALSA or MPD fault.

```sh
dmesg | grep -i -E 'usb|error -71' | tail -20
dmesg | grep -c 'USB disconnect'
```

- Use the **front USB 3.0** port, direct, without a hub; the rear USB 2.0 port
  produced `error -71` on this unit.
- Try another cable before touching any configuration.
- After the change the disconnect count should stay at 0 over a long playback run.

## DSD files are silent or converted

The default output is native DSD (`dop "no"`). Check:

- `dop "no"` is in the `audio_output` block, and `mixer_type` is `"none"`.
- `cat /proc/asound/card0/pcm0p/sub0/hw_params` shows `DSD_U32_BE` at 176400 or
  705600 Hz for native DSD.
- If it shows `S32_LE` at 176400, 352800 or 705600 Hz, the output is DoP
  (`dop "yes"`).
- Native DSD needs a DAC that accepts the `DSD_U32_BE` altset. The DX5 II does;
  another DAC may need `dop "yes"`.
- DSD64, DSD128 and DSD256 work over DoP; DSD512 needs native DSD.
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
ls -ld /etc/mympd /var/cache/mympd
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

## Bit-transparent checklist

- `device "hw:0,0"` (not `default`/`plughw`).
- `mixer_type "none"`.
- No `format`, `samplerate_converter` or ALSA plugins in the chain.
- DAC volume at 0 dB / fixed.
- DSD is native by default (`dop "no"`); DoP only if the DAC needs it
  (`dop "yes"`).
