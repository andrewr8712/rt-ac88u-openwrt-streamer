# Build notes

How this image was produced. Everything is reproducible from an x86_64 Linux
host with ~15 GB free disk, `wget`, `zstd`, `tar`, `git`, `cmake`, `gcc`.

## 1. Base image (Image Builder)

```sh
wget https://downloads.openwrt.org/releases/24.10.8/targets/bcm53xx/generic/\
openwrt-imagebuilder-24.10.8-bcm53xx-generic.Linux-x86_64.tar.zst
tar --zstd -xf openwrt-imagebuilder-24.10.8-bcm53xx-generic.Linux-x86_64.tar.zst
cd openwrt-imagebuilder-24.10.8-bcm53xx-generic.Linux-x86_64

make image \
  PROFILE="asus_rt-ac88u" \
  PACKAGES="kmod-sound-core kmod-usb-audio alsa-utils usbutils mpd-mini upmpdcli \
            block-mount kmod-usb-storage kmod-fs-ext4 kmod-fs-vfat kmod-fs-exfat \
            kmod-fs-cifs cifsmount libopenssl3 libpcre2 \
            luci-base luci-mod-system luci-mod-network luci-mod-status \
            luci-mod-dashboard luci-theme-bootstrap luci-app-package-manager uhttpd \
            -firewall4 -nftables -kmod-nft-offload -dnsmasq -odhcpd-ipv6only \
            -odhcp6c -ppp -ppp-mod-pppoe \
            -wpad-basic-mbedtls -kmod-brcmfmac \
            -brcmfmac-firmware-4366b1-pcie -brcmfmac-firmware-4366c0-pcie -iwinfo" \
  FILES="/path/to/ovl"
```

`ovl/` is the overlay directory from this repo; it supplies the custom binaries
and first-boot scripts.

## 2. Custom MPD with DSD

The stock `mpd-mini` package is built with `-Ddsd=false`, so DSF/DFF cannot be
decoded. The fix is a rebuild with `-Ddsd=true`.

1. Clone/install the `packages` feed for 24.10 into an OpenWrt SDK.
2. Patch `feeds/packages/sound/mpd/Makefile`:
   - `PKG_RELEASE:=3` (so the custom build wins over the repo version)
   - `-Ddsd=false` → `-Ddsd=true`
3. Apply the feed's libfmt-11 patch (`040-lib-fmt-support-build-with-libfmt-11.0.0.patch`)
   and `030-no-avfilter.patch`. Skip `020-string-view.patch` (needs a boost
   header that this boost release does not ship; `std::string_view` works).
4. Remove the `mpd-full` and `mpd-avahi-service` variants if you only build mini
   (the directory target otherwise builds PulseAudio deps too).
5. Build with `make package/feeds/packages/mpd/compile` **or** cross-compile
   manually with meson against the SDK staging libs:

```sh
meson setup build --cross-file build/mpd-cross.txt --buildtype=release \
  -Ddsd=true -Dalsa=enabled -Dflac=enabled -Dmad=enabled -Dfaad=enabled \
  -Dopus=enabled -Dtremor=enabled -Dvorbis=disabled -Dffmpeg=disabled \
  -Dpulse=disabled -Dupnp=disabled -Dzeroconf=disabled -Ddbus=disabled \
  -Dmms=disabled -Dsoxr=disabled -Dyajl=disabled -Dshout=disabled \
  -Drecorder=false -Dfifo=false -Dpipe=false -Ddatabase=true \
  -Dcurl=enabled -Dlibmpdclient=enabled -Ddocumentation=disabled \
  -Dmanpages=false -Dtest=false -Ddaemon=false -Dsystemd=disabled
ninja -C build
```

Disabling `zeroconf`/`dbus`/`mms`/`soxr`/`yajl` is important: with them left on
`auto`, meson links against libraries that are not in the final image.

## 3. myMPD

myMPD is not packaged in the 24.10 feeds, so it is cross-compiled with cmake.

Build its two missing dependencies into the SDK staging dir first:

- **PCRE2 10.42** — `--host=arm-openwrt-linux-muslgnueabi --disable-static --enable-shared --enable-pcre2-8`
- **OpenSSL 3.0.21** — `./Configure linux-armv4 no-tests shared --cross-compile-prefix=arm-openwrt-linux-muslgnueabi-`

Then:

```sh
cmake -S myMPD -B build \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/build/mympd-toolchain.cmake \
  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
  -DMATH_LIB=/path/to/toolchain/libm.a \
  -DMYMPD_EMBEDDED_ASSETS=ON -DMYMPD_EMBEDDED_LIBMPDCLIENT=OFF \
  -DMYMPD_ENABLE_LUA=OFF -DMYMPD_ENABLE_UTF8=OFF \
  -DMYMPD_ENABLE_LIBID3TAG=OFF -DMYMPD_ENABLE_FLAC=OFF \
  -DMYMPD_DOC=OFF -DMYMPD_DOC_HTML=OFF -DMYMPD_MANPAGES=OFF \
  -DMYMPD_STARTUP_SCRIPT=OFF \
  -DCMAKE_C_FLAGS="-I/path/to/myMPD/dist/libmpdclient/include"
cmake --build build -j$(nproc)
```

Notes:

- `MYMPD_EMBEDDED_LIBMPDCLIENT=OFF` lets cmake notice the staging libmpdclient is
  too old (2.22 < 2.26) and fall back to the bundled copy **with** the required
  compile define. Forcing `ON` skips that define and mixes headers.
- `-Werror` in `CMakeLists.txt` breaks the vendored mongoose build on GCC 13;
  remove that flag.
- `MYMPD_ENABLE_LIBID3TAG`/`FLAC` are optional myMPD-side file parsers. MPD still
  decodes FLAC and serves tags/artwork, so disabling them does not affect
  playback.

## 4. Overlay

`ovl/` contains:

| File | Purpose |
|---|---|
| `usr/bin/mpd` | DSD-enabled MPD binary |
| `usr/bin/mympd` | myMPD binary (assets embedded) |
| `etc/init.d/mympd` | procd service, runs as `mympd` |
| `etc/uci-defaults/98-mympd-user` | creates the `mympd` user/group |
| `etc/uci-defaults/99-lan-dhcp` | first boot: LAN becomes a DHCP client |

Pass `FILES=/path/to/ovl` to the image builder as shown above.

## 5. Result

`bin/targets/bcm53xx/generic/openwrt-24.10.8-bcm53xx-generic-asus_rt-ac88u-squashfs.trx`
(~14 MB) — published as a GitHub Release asset.
