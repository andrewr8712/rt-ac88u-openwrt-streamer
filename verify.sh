#!/bin/sh
# verify.sh - consistency, privacy and artifact checks for this repository.
#
# Run from the repository root:  ./verify.sh
# Optional: IMAGE=path/to/image.trx ./verify.sh   (checks the SHA against README)
#
set -u
fail=0
ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

READELF="${READELF:-readelf}"

# ---- binaries --------------------------------------------------------------
for b in ovl/usr/bin/mpd ovl/usr/bin/mympd; do
	[ -f "$b" ] || { bad "missing $b"; continue; }
	if strings "$b" | grep -q '/home/'; then
		bad "$b contains a build-host path"
	else
		ok "$b has no build-host paths"
	fi
	if "$READELF" -d "$b" 2>/dev/null | grep -qi 'rpath\|runpath'; then
		bad "$b has RPATH/RUNPATH"
	else
		ok "$b has no RPATH/RUNPATH"
	fi
done

# ---- overlay is the source of truth ---------------------------------------
grep -q 'bind_to_address[[:space:]]*"any"' ovl/etc/mpd.conf 2>/dev/null \
	&& ok "mpd.conf binds to any" || bad "mpd.conf missing bind_to_address any"
grep -q 'GROUP="audio"' ovl/etc/init.d/mpd 2>/dev/null \
	&& ok "mpd init uses audio group" || bad "mpd init does not use audio group"
grep -q "mympd:x:91:91:mympd:/etc/mympd" ovl/etc/uci-defaults/98-mympd-user 2>/dev/null \
	&& ok "myMPD uid 91 / /etc/mympd" || bad "myMPD uid/home wrong"
grep -q '\-w /etc/mympd' ovl/etc/init.d/mympd 2>/dev/null \
	&& ok "myMPD workdir is /etc/mympd" || bad "myMPD workdir is not persistent"
[ -f ovl/etc/rc.local ] && ok "rc.local baked in" || bad "rc.local missing"

# ---- setup script no longer patches the image -----------------------------
if grep -q 'sed -i' post-flash-setup.sh; then
	bad "post-flash-setup.sh still patches files with sed"
else
	ok "setup script is configuration-only"
fi

# ---- documentation facts ---------------------------------------------------
grep -q 'DSD64/128/256' README.md 2>/dev/null || bad "README does not state DSD64/128/256"
grep -q 'DSD64/128/256' docs/HARDWARE.md 2>/dev/null || bad "HARDWARE does not state DSD64/128/256"
grep -q 'DSD256' docs/TROUBLESHOOTING.md 2>/dev/null || bad "TROUBLESHOOTING does not mention DSD256"
grep -rq '109 MB' README.md docs WORKFLOW.md PROJECT-REPORT.md 2>/dev/null \
	&& bad "stale 109 MB overlay figure" || ok "overlay size consistent"
grep -rq 'loglevel=3\|loglevel 3' README.md docs post-flash-setup.sh 2>/dev/null \
	&& bad "stale loglevel 3" || ok "loglevel is 4 (warn)"
grep -q '/var/lib/mympd' docs/TROUBLESHOOTING.md 2>/dev/null \
	&& bad "TROUBLESHOOTING still references /var/lib/mympd" || ok "troubleshooting paths current"

# ---- privacy ---------------------------------------------------------------
if grep -rIn --exclude-dir=.git -E '10\.0\.0\.[0-9]+|/home/andrew|SMB_USER="andrew"' \
	README.md docs WORKFLOW.md PROJECT-REPORT.md post-flash-setup.sh bench ovl 2>/dev/null | grep -v 'Binary'; then
	bad "private identifiers found"
else
	ok "no private identifiers in tracked text"
fi

# ---- optional image check --------------------------------------------------
if [ -n "${IMAGE:-}" ]; then
	if [ -f "$IMAGE" ]; then
		sum=$(sha256sum "$IMAGE" | cut -d' ' -f1)
		if grep -q "$sum" README.md; then
			ok "image SHA matches README"
		else
			bad "image SHA $sum not in README"
		fi
	else
		bad "IMAGE not found: $IMAGE"
	fi
fi

echo
[ "$fail" -eq 0 ] && echo "all checks passed" || echo "some checks failed"
exit "$fail"
