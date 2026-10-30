#!/bin/sh
# build.sh - rebuild the streamer binaries and the flashable image.
#
# Required environment:
#   SDK=/path/to/openwrt-sdk-24.10.8-bcm53xx-generic...
#   IMAGEBUILDER=/path/to/openwrt-imagebuilder-24.10.8-bcm53xx-generic...
#   SRC_MPD=/path/to/mpd-0.23.15
#   SRC_MYMPD=/path/to/myMPD-26.1.1
#
# Optional: OUT=directory for the resulting .trx (default: ./out)
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${SDK:?set SDK}" "${IMAGEBUILDER:?set IMAGEBUILDER}"
: "${SRC_MPD:?set SRC_MPD}" "${SRC_MYMPD:?set SRC_MYMPD}"
OUT=${OUT:-$ROOT/out}
mkdir -p "$OUT"

TC=$SDK/staging_dir/toolchain-arm_cortex-a9_gcc-13.3.0_musl_eabi/bin
TGT=$SDK/staging_dir/target-arm_cortex-a9_musl_eabi
export STAGING_DIR=$SDK/staging_dir
export PKG_CONFIG_LIBDIR=$TGT/usr/lib/pkgconfig:$TGT/usr/share/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=$TGT
export BOOST_ROOT=$TGT/usr BOOST_INCLUDEDIR=$TGT/usr/include BOOST_LIBRARYDIR=$TGT/usr/lib
PREFIX_MAP="-ffile-prefix-map=$ROOT=/build -fmacro-prefix-map=$ROOT=/build"

echo ">> MPD"
if [ ! -f "$SRC_MPD/build/build.ninja" ]; then
	meson setup "$SRC_MPD/build" --cross-file "$ROOT/build/mpd-cross.txt" \
		--prefix=/usr --buildtype=release -Ddsd=true -Dalsa=enabled \
		-Dflac=enabled -Dmad=enabled -Dfaad=enabled -Dopus=enabled -Dtremor=enabled \
		-Dvorbis=disabled -Dffmpeg=disabled -Dpulse=disabled -Dupnp=disabled \
		-Dzeroconf=disabled -Ddbus=disabled -Dmms=disabled -Dsoxr=disabled \
		-Dyajl=disabled -Dshout=disabled -Drecorder=false -Dfifo=false -Dpipe=false \
		-Dsndfile=disabled -Dwebdav=disabled -Dqobuz=disabled -Dsoundcloud=disabled \
		-Dlame=disabled -Dtwolame=disabled -Dshine=disabled -Dvorbisenc=disabled \
		-Dlibsamplerate=disabled -Dmpg123=disabled -Djack=disabled -Dopenal=disabled \
		-Doss=disabled -Dpipewire=disabled -Dsndio=disabled -Dsqlite=disabled \
		-Ddatabase=true -Dcurl=enabled -Dlibmpdclient=enabled \
		-Ddocumentation=disabled -Dmanpages=false -Dtest=false -Ddaemon=false \
		-Dsystemd=disabled
fi
ninja -C "$SRC_MPD/build"
"$TC/arm-openwrt-linux-muslgnueabi-strip" "$SRC_MPD/build/mpd"
"$SDK/staging_dir/host/bin/patchelf" --remove-rpath "$SRC_MPD/build/mpd" || true

echo ">> myMPD"
if grep -q '"-Werror"' "$SRC_MYMPD/CMakeLists.txt"; then
	(cd "$SRC_MYMPD" && patch -p1 < "$ROOT/patches/mympd-26.1.1-remove-werror.patch")
fi
rm -rf "$SRC_MYMPD/build-openwrt"
"$SDK/staging_dir/host/bin/cmake" -S "$SRC_MYMPD" -B "$SRC_MYMPD/build-openwrt" \
	-DCMAKE_TOOLCHAIN_FILE="$ROOT/build/mympd-toolchain.cmake" \
	-DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
	-DMATH_LIB="$SDK/staging_dir/toolchain-arm_cortex-a9_gcc-13.3.0_musl_eabi/arm-openwrt-linux-muslgnueabi/lib/libm.a" \
	-DMYMPD_EMBEDDED_ASSETS=ON -DMYMPD_ENABLE_LUA=OFF -DMYMPD_ENABLE_UTF8=OFF \
	-DMYMPD_DOC=OFF -DMYMPD_DOC_HTML=OFF -DMYMPD_MANPAGES=OFF \
	-DMYMPD_STARTUP_SCRIPT=OFF -DMYMPD_EMBEDDED_LIBMPDCLIENT=OFF \
	-DMYMPD_ENABLE_FLAC=OFF -DMYMPD_ENABLE_LIBID3TAG=OFF -DMYMPD_BUILD_TESTING=OFF \
	-DCMAKE_C_FLAGS="-I$SRC_MYMPD/dist/libmpdclient/include $PREFIX_MAP" \
	-DCMAKE_EXE_LINKER_FLAGS="-L$TGT/usr/lib -Wl,-rpath-link,$TGT/usr/lib"
"$SDK/staging_dir/host/bin/cmake" --build "$SRC_MYMPD/build-openwrt" -j4
"$TC/arm-openwrt-linux-muslgnueabi-strip" "$SRC_MYMPD/build-openwrt/bin/mympd"
"$SDK/staging_dir/host/bin/patchelf" --remove-rpath "$SRC_MYMPD/build-openwrt/bin/mympd" || true

echo ">> installing into overlay"
cp "$SRC_MPD/build/mpd" "$ROOT/ovl/usr/bin/mpd"
cp "$SRC_MYMPD/build-openwrt/bin/mympd" "$ROOT/ovl/usr/bin/mympd"

echo ">> image"
make -C "$IMAGEBUILDER" image PROFILE=asus_rt-ac88u \
	PACKAGES="$(sed -n 's/^PACKAGES="\(.*\)"/\1/p' "$ROOT/build/packages.txt")" \
	FILES="$ROOT/ovl"
cp "$IMAGEBUILDER"/bin/targets/bcm53xx/generic/*ac88u*squashfs.trx "$OUT/"
(cd "$OUT" && sha256sum *.trx > SHA256SUMS)
echo ">> done: $OUT"
