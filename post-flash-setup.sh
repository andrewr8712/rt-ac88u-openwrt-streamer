#!/bin/sh
#
# post-flash-setup.sh - configure the RT-AC88U OpenWrt image as a persistent
# MPD + UPnP + myMPD music streamer with an SMB library.
#
# EDIT THE SMB SETTINGS BELOW before running.
#
# Usage (from your PC):
#   scp post-flash-setup.sh root@<router-ip>:/tmp/
#   ssh root@<router-ip> sh /tmp/post-flash-setup.sh
#
set -e

# ---- SMB library -----------------------------------------------------------
SMB_SERVER="10.0.0.216"        # NAS / PC address
SMB_SHARE="public"             # share name
SMB_USER="andrew"
SMB_PASS="CHANGE_ME"           # <-- set this
MOUNT_POINT="/mnt/music"
# ---------------------------------------------------------------------------

MPD_USER="mpd"
MYMPD_UID="91"

echo ">> MPD: persistent state directory"
mkdir -p /etc/mpd/playlists
chown -R "$MPD_USER:$MPD_USER" /etc/mpd

echo ">> MPD: audio group (device nodes are root:audio 660)"
if ! grep -q '^audio:.*mpd' /etc/group; then
	sed -i 's/^\(audio:x:[0-9]*:\).*/\1mpd/' /etc/group
fi
# run mpd with audio as primary group as well
sed -i 's/^GROUP="mpd"/GROUP="audio"/' /etc/init.d/mpd

echo ">> MPD: configuration"
cat > /etc/mpd.conf <<'EOF'
music_directory     "/mnt/music"
playlist_directory  "/etc/mpd/playlists"
db_file             "/etc/mpd/tag_cache"
state_file          "/etc/mpd/state"
log_file            "syslog"
log_level           "error"
user                "mpd"
bind_to_address     "any"
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

echo ">> myMPD: dedicated user/workdir (uid $MYMPD_UID, avoids upmpdcli's 89)"
grep -q '^mympd:' /etc/passwd || \
	echo "mympd:x:${MYMPD_UID}:${MYMPD_UID}:mympd:/etc/mympd:/bin/false" >> /etc/passwd
grep -q '^mympd:' /etc/group || \
	echo "mympd:x:${MYMPD_UID}:" >> /etc/group
# migrate an earlier install that used uid 89
sed -i 's/^mympd:x:89:89:/mympd:x:91:91:/' /etc/passwd
sed -i 's/^mympd:x:89:/mympd:x:91:/' /etc/group

mkdir -p /etc/mympd/config /etc/mympd/state /var/cache/mympd
printf 'false\n' > /etc/mympd/config/ssl           # plain HTTP on :8080
printf '3\n' > /etc/mympd/config/loglevel           # 3 = info, less noise than default
printf '%s\n' "$MOUNT_POINT" > /etc/mympd/state/music_directory
chown -R mympd:mympd /etc/mympd
chown -R mympd:mympd /var/cache/mympd

# myMPD init: persistent workdir instead of /var/lib/mympd
sed -i 's#-w /var/lib/mympd#-w /etc/mympd#' /etc/init.d/mympd 2>/dev/null || true
sed -i 's#mkdir -p /var/lib/mympd /var/cache/mympd#mkdir -p /etc/mympd /var/cache/mympd#' /etc/init.d/mympd 2>/dev/null || true
sed -i 's#chown mympd:mympd /var/lib/mympd /var/cache/mympd#chown -R mympd:mympd /etc/mympd; chown -R mympd:mympd /var/cache/mympd#' /etc/init.d/mympd 2>/dev/null || true

echo ">> boot-time directory service (tmpfs is wiped every boot)"
cat > /etc/init.d/mpd-dirs <<'EOS'
#!/bin/sh /etc/rc.common
START=92
start() {
	mkdir -p /etc/mpd/playlists /etc/mympd
	chown -R mpd:mpd /etc/mpd
	chown -R mympd:mympd /etc/mympd
}
EOS
chmod +x /etc/init.d/mpd-dirs
/etc/init.d/mpd-dirs enable

echo ">> SMB mount (static /etc/fstab; UCI fstab is not honoured by block mount)"
mkdir -p "$MOUNT_POINT"

if [ -n "$SMB_SERVER" ] && [ "$SMB_PASS" != "CHANGE_ME" ]; then
	printf 'username=%s\npassword=%s\n' "$SMB_USER" "$SMB_PASS" > /etc/smbcredentials
	chmod 600 /etc/smbcredentials
	MPD_UID_N=$(id -u mpd)
	MPD_GID_N=$(id -g mpd)
	grep -q "//$SMB_SERVER/$SMB_SHARE" /etc/fstab 2>/dev/null || \
		echo "//$SMB_SERVER/$SMB_SHARE $MOUNT_POINT cifs credentials=/etc/smbcredentials,vers=3.0,iocharset=utf8,uid=$MPD_UID_N,gid=$MPD_GID_N,actimeo=60,ro 0 0" >> /etc/fstab
	mount -a || echo "WARNING: SMB mount failed - check server/share/credentials"
else
	echo "NOTE: SMB_PASS is unset (CHANGE_ME); leaving /etc/smbcredentials and"
	echo "      /etc/fstab untouched. Edit them manually or re-run with the password."
fi
/etc/init.d/fstab enable

echo ">> boot hook: mount the share, then (re)start the players"
cat > /etc/rc.local <<'EOS'
#!/bin/sh
(
	i=0
	while [ $i -lt 30 ]; do
		grep -q ' /mnt/music ' /proc/mounts && break
		mount -a 2>/dev/null
		sleep 2
		i=$((i+1))
	done
	/etc/init.d/mpd restart
	/etc/init.d/upmpdcli restart
) &
exit 0
EOS
chmod +x /etc/rc.local

echo ">> upmpdcli"
uci -q set upmpdcli.lan.friendly_name='RT-AC88U Music'
uci -q set upmpdcli.lan.mpd_host='127.0.0.1'
uci -q set upmpdcli.lan.mpd_port='6600'
uci -q commit upmpdcli 2>/dev/null || true

echo ">> enabling services"
for s in mpd upmpdcli mympd mpd-dirs; do
	/etc/init.d/$s enable 2>/dev/null || true
done

echo ">> disabling services that are not needed here"
for s in packet_steering cron gpio_switch; do
	/etc/init.d/$s disable 2>/dev/null || true
done

/etc/init.d/mpd restart
/etc/init.d/upmpdcli restart
/etc/init.d/mympd restart

sleep 2

echo
echo ">> ALSA playback devices:"
aplay -l 2>/dev/null || true
echo
echo ">> USB devices (look for the DAC):"
lsusb 2>/dev/null | grep -i -e topping -e thesycon || true
echo
echo ">> Done."
echo "   myMPD: http://<router-ip>:8080"
echo "   LuCI:  http://<router-ip>/"
echo "   If the library is empty, wait for the scan or run:"
echo "     printf 'update\\nclose\\n' | nc 127.0.0.1 6600"
