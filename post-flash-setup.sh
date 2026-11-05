#!/bin/sh
#
# post-flash-setup.sh - attach the SMB library and start the player stack.
#
# All player configuration (MPD, myMPD, audio group, persistent dirs, boot
# order) is baked into the image overlay. This script only handles what cannot
# be baked: SMB credentials, the mount entry, and verification.
#
# The SMB settings come from the environment, so no password is ever stored in
# this tracked file. Usage (from your PC):
#
#   scp post-flash-setup.sh root@<router-ip>:/tmp/
#   ssh -t root@<router-ip> \
#       SMB_SERVER=192.168.1.10 SMB_SHARE=Music SMB_USER=andrew SMB_PASS='...' \
#       sh /tmp/post-flash-setup.sh
#
# If you omit SMB_PASS, the script runs the rest of the bring-up and leaves
# /etc/smbcredentials and /etc/fstab untouched.
#
set -e

# ---- SMB library -----------------------------------------------------------
SMB_SERVER="${SMB_SERVER:-192.168.1.10}"   # NAS / PC address
SMB_SHARE="${SMB_SHARE:-Music}"            # share name
SMB_USER="${SMB_USER:-USER}"
SMB_PASS="${SMB_PASS:-}"                   # never hardcode this
MOUNT_POINT="/mnt/music"
# ---------------------------------------------------------------------------

echo ">> checking baked configuration"
[ -f /etc/mpd.conf ] || { echo "ERROR: /etc/mpd.conf missing - wrong image?"; exit 1; }
mkdir -p "$MOUNT_POINT" /etc/mpd /etc/mympd
chown -R mpd:mpd /etc/mpd 2>/dev/null || true
chown -R mympd:mympd /etc/mympd 2>/dev/null || true

echo ">> SMB mount"
if [ -n "$SMB_SERVER" ] && [ -n "$SMB_PASS" ]; then
	printf 'username=%s\npassword=%s\n' "$SMB_USER" "$SMB_PASS" > /etc/smbcredentials
	chmod 600 /etc/smbcredentials
	MPD_UID_N=$(id -u mpd)
	MPD_GID_N=$(id -g mpd)
	grep -q "//$SMB_SERVER/$SMB_SHARE" /etc/fstab 2>/dev/null || \
		echo "//$SMB_SERVER/$SMB_SHARE $MOUNT_POINT cifs credentials=/etc/smbcredentials,vers=3.0,iocharset=utf8,uid=$MPD_UID_N,gid=$MPD_GID_N,actimeo=60,ro 0 0" >> /etc/fstab
	mount -a || echo "WARNING: SMB mount failed - check server/share/credentials"
else
	echo "NOTE: SMB_PASS is unset; leaving /etc/smbcredentials and /etc/fstab"
	echo "      untouched. Re-run with SMB_PASS='...' to mount the library."
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
