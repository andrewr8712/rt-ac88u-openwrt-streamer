#!/bin/sh
#
# post-flash-setup.sh - attach the SMB library and start the player stack.
#
# All player configuration (MPD, myMPD, audio group, persistent dirs, boot
# order) is baked into the image overlay. This script only handles what cannot
# be baked: SMB credentials, the mount entry, and verification.
#
# EDIT THE SMB SETTINGS BELOW before running.
#
# Usage (from your PC):
#   scp post-flash-setup.sh root@<router-ip>:/tmp/
#   ssh root@<router-ip> sh /tmp/post-flash-setup.sh
#
set -e

# ---- SMB library -----------------------------------------------------------
SMB_SERVER="192.168.1.10"      # NAS / PC address
SMB_SHARE="Music"              # share name
SMB_USER="USER"
SMB_PASS="CHANGE_ME"           # <-- set this
MOUNT_POINT="/mnt/music"
# ---------------------------------------------------------------------------

echo ">> checking baked configuration"
[ -f /etc/mpd.conf ] || { echo "ERROR: /etc/mpd.conf missing - wrong image?"; exit 1; }
mkdir -p "$MOUNT_POINT" /etc/mpd /etc/mympd
chown -R mpd:mpd /etc/mpd 2>/dev/null || true
chown -R mympd:mympd /etc/mympd 2>/dev/null || true

echo ">> SMB mount"
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
	echo "      /etc/fstab untouched."
fi
/etc/init.d/fstab enable 2>/dev/null || true

echo ">> enabling services"
for s in mpd upmpdcli mympd; do
	/etc/init.d/$s enable 2>/dev/null || true
done

echo ">> restarting services"
/etc/init.d/mpd restart
/etc/init.d/upmpdcli restart
/etc/init.d/mympd restart

sleep 2

echo
echo ">> mount:"
grep ' /mnt/music ' /proc/mounts || echo "  NOT MOUNTED"
echo ">> ALSA devices:"
aplay -l 2>/dev/null || true
echo ">> USB:"
lsusb 2>/dev/null | grep -i -e topping -e thesycon || true
echo ">> MPD:"
printf 'stats\nclose\n' | nc 127.0.0.1 6600 2>/dev/null | grep -E 'songs|albums' || true
echo
echo ">> Done."
echo "   myMPD: http://<router-ip>:8080"
echo "   LuCI:  http://<router-ip>/"
echo "   If the library is empty, wait for the scan or run:"
echo "     printf 'update\\nclose\\n' | nc 127.0.0.1 6600"
