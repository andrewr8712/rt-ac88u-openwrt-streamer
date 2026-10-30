#!/bin/sh
#
# post-flash-setup.sh - turn the RT-AC88U OpenWrt image into an MPD + UPnP
# music appliance driving a USB DAC (Topping DX5 II), with AT LEAST the
# stock packages: mpd-mini, upmpdcli, alsa-utils, usbutils.
#
# Prerequisite: the router is flashed with
#   openwrt-24.10.8-bcm53xx-generic-asus_rt-ac88u-squashfs.trx
# and you can SSH in as root.
#
# Usage (from your PC):
#   scp post-flash-setup.sh root@192.168.1.1:/tmp/
#   ssh root@192.168.1.1 sh /tmp/post-flash-setup.sh
#
set -e

MUSIC_DIR="/mnt/music"   # SMB share mountpoint

echo ">> Writing /etc/mpd.conf (ALSA -> USB DAC, no PulseAudio)"
cat > /etc/mpd.conf <<'EOF'
music_directory     "/mnt/music"
playlist_directory  "/var/lib/mpd/playlists"
db_file             "/var/lib/mpd/tag_cache"
state_file          "/var/lib/mpd/state"
log_file            "syslog"
user                "mpd"
bind_to_address     "127.0.0.1"
port                "6600"
auto_update         "yes"
restore_paused      "yes"

audio_output {
    type        "alsa"
    name        "Topping DX5 II"
    device      "hw:0,0"      # USB DAC is card 0 (no onboard sound)
    mixer_type  "none"        # use the DAC's own volume knob
    dop         "yes"         # DSD-over-PCM (DSD64/128 on Topping)
}
EOF

echo ">> Creating MPD state dirs and music library dir"
mkdir -p /var/lib/mpd/playlists "$MUSIC_DIR"
chown -R mpd:mpd /var/lib/mpd 2>/dev/null || true

echo ">> Configuring upmpdcli (UPnP/DLNA renderer that fronts MPD)"
uci -q set upmpdcli.lan.friendly_name='RT-AC88U Music'
uci -q set upmpdcli.lan.mpd_host='127.0.0.1'
uci -q set upmpdcli.lan.mpd_port='6600'
uci -q commit upmpdcli 2>/dev/null || true

echo ">> Enabling services at boot"
/etc/init.d/mpd enable
/etc/init.d/upmpdcli enable
/etc/init.d/mympd enable
/etc/init.d/mpd restart
/etc/init.d/upmpdcli restart
/etc/init.d/mympd restart

echo
echo ">> ALSA playback devices detected:"
aplay -l 2>/dev/null || true
echo
echo ">> USB devices (look for your Topping):"
lsusb 2>/dev/null || true
echo
echo ">> Done."
echo "   - Mount your SMB share at /mnt/music (see README-build.md)."
echo "   - Web UI: http://<router-ip>:8080  (myMPD)"
echo "   - Admin:  http://<router-ip>/     (LuCI)"
