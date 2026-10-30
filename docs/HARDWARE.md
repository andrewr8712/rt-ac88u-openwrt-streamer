# Hardware notes

## Router: ASUS RT-AC88U

| | |
|---|---|
| SoC | Broadcom BCM4709C0 — dual-core ARM Cortex-A9 @ 1.4 GHz |
| RAM | 512 MB |
| Flash | 128 MB NAND (SLC) — ~109 MB usable overlay after flashing |
| USB | 1× USB 3.0 + 1× USB 2.0, both host mode |
| Ethernet | 8× GbE (BCM53012 switch + Realtek RTL8365MB for LAN5–8) |
| Wi-Fi | 2× BCM4366 (2.4/5 GHz) — **not usable** under OpenWrt |
| Serial | 115200 8N1, 3.3 V, internal header |

### Wi-Fi

The BCM4366 radios are only supported by `brcmfmac`, which has no working AP
mode and incomplete station mode for this chip. Treat the device as wired-only.
That is why `wpad`, `kmod-brcmfmac`, the 4366 firmware packages and `iwinfo`
are not installed.

### Flashing

CFE recovery: hold **Reset** while powering on until the power LED blinks
slowly, PC at `192.168.1.2/24`, browse to `http://192.168.1.1`, reset NVRAM,
upload the `.trx`. Alternatively use the ASUS Firmware Restoration tool.

## DAC: Topping DX5 II

| | |
|---|---|
| Type | Desktop DAC / headphone amp, dual ES9039Q2M |
| Input | USB (UAC2 class-compliant), plus coax/optical/Bluetooth |
| PCM | up to 768 kHz |
| DSD | up to DSD512 (native); DoP for DSD64/128 |
| Power | Mains-powered (not USB bus powered) |

Because it is UAC2 class-compliant it works with the kernel's `snd-usb-audio`
driver without vendor drivers. With no other sound card present it enumerates as
ALSA **card 0**, so MPD's output is `device "hw:0,0"`.

`mixer_type "none"` is used: MPD does not touch the DAC's mixer; use the DX5 II's
own volume control. For strict bit-perfect output, run the DAC at 0 dB / fixed
volume and attenuate downstream.

USB 2.0 is sufficient for UAC2 (including DoP at 352.8 kHz). The USB 3.0 port
works too.
