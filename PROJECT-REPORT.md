# RT-AC88U OpenWrt Music Streamer — Project Report

**Date:** 30 October 2026 · **Status:** Delivered, deployed and validated on hardware
**Session:** `session-ae0964a9`

---

## Executive summary

| Metric | Value |
|---|---|
| Wall-clock time | **9 h 40 m** (09:46 → 19:26 AWST) |
| Model calls | **493** |
| Total tokens | **178,485,851** |
| Cache hit rate | **99.80 %** |
| Total API cost | **$1.48 USD** |
| Final image | 13 MB, SHA256 `612fe897…a8a9fd` |
| Live library | 1,965 songs / 135 albums / 108 DSD files |
| Deliverables | flashable image, GitHub repo, v1.0 release, baseline benchmarks |

The project took ~2 h 45 m to produce a release candidate, then another ~7 h of
hardware bring-up, debugging, persistence hardening, tuning and benchmarking on
the real router.

---

## 1. Token usage

| Model | Calls | Input (cache miss) | Input (cache hit) | Output | Total |
|---|---:|---:|---:|---:|---:|
| `deepseek-v4-pro` | 6 | 35,274 | 134,528 | 17,781 | 187,583 |
| `deepseek-flash` | 487 | 319,208 | 177,539,584 | 439,476 | 178,298,268 |
| **Total** | **493** | **354,482** | **177,674,112** | **457,257** | **178,485,851** |

- Cache hit ratio: **99.80 %** of all prompt tokens
- Average per call: ~362,000 tokens total, ~927 output tokens
- Cache writes: 0
- Search/fetch requests: 11 (free until 1 Nov 2026)

The large total is normal for an agentic session: every call re-sends the
conversation context, and almost all of it is served from the prompt cache.
Only ~354 K tokens were uncached input across the whole project.

---

## 2. Cost

### Rates used

Source: [DeepSeek API — Models & Pricing](https://api-docs.deepseek.com/quick_start/pricing/), accessed 30 Oct 2026. USD per 1M tokens.

| Model | Cache hit (off-peak / peak) | Cache miss (off-peak / peak) | Output (off-peak / peak) |
|---|---|---|---|
| `deepseek-v4-pro` | $0.022 / $0.044 | $0.66 / $1.32 | $1.98 / $3.96 |
| `deepseek-flash` | $0.003 / $0.006 | $0.15 / $0.30 | $0.60 / $1.20 |

Peak hours: 01:00–04:00 and 06:00–10:00 UTC, Monday–Friday (Chinese public holidays excluded).

### Result

| Model | Calls | Peak / off-peak calls | Cost |
|---|---:|---:|---:|
| `deepseek-v4-pro` | 6 | 6 / 0 | **$0.1229** |
| `deepseek-flash` | 487 | 341 / 146 | **$1.3576** |
| — of which peak | | | $1.0268 |
| — of which off-peak | | | $0.3308 |
| **Total** | **493** | **347 / 146** | **$1.4805** |

**Rounded total: $1.48 USD** — average $0.0030 per model call.

Notes:

- The first phase (09:46–12:00 AWST = 01:46–04:00 UTC) fell entirely inside the
  peak window on a Friday. Work after 12:00 AWST (146 calls) was billed off-peak.
- The 11 search/fetch requests are currently free; per-request billing starts
  1 Nov 2026.
- Costs are computed per call from recorded usage, not from an aggregate estimate.

---

## 3. Timeline

| Time (AWST) | Phase |
|---|---|
| 09:46 | Research, platform validation, architecture decisions |
| 10:07 | First image (17 MB, rejected: PulseAudio bloat) |
| 10:08 | Lean 11 MB image (`mpd-mini`) |
| 10:55 | Custom DSD-enabled MPD compiled |
| 11:08 | DHCP-client LAN variant |
| 11:38 | myMPD cross-compiled |
| 11:41 | Final 14 MB image (LuCI + myMPD + SMB) |
| 12:01 | GitHub repo + v1.0 release published |
| 15:16 | Flashed to hardware; first boot success |
| 15:20–17:00 | Playback bring-up: USB stability, audio group, DSD256 verification |
| 17:20–17:45 | Persistence fixes (MPD DB, myMPD state, SMB mount at boot) |
| 18:00–18:30 | M.A.L.P./MPD binding, HTTP/HSTS fix |
| 18:38 | Optimisation pass (dead services, log levels, CIFS `actimeo`) |
| 19:15 | Raw benchmark suite run |
| 19:26 | Documentation, reports, repo sync |

---

## 4. Bring-up findings and fixes

These only surfaced on real hardware; all are now in `post-flash-setup.sh`.

| Symptom | Root cause | Fix |
|---|---|---|
| `Failed to open hw:0,0` | `mpd` not in `audio` group (`/dev/snd` is `root:audio 660`) | run MPD with `GROUP="audio"`; add `mpd` to `audio` |
| DAC repeatedly re-enumerating (`error -71`, “attempt power cycle”) | marginal cable/USB2 port | stable port + cable; **0 disconnects** afterwards |
| MPD DB lost every reboot | `db_file` under `/var` (tmpfs) | move DB/state/playlists to `/etc/mpd` |
| myMPD settings reset | workdir under `/var`; uid 89 collided with upmpdcli | workdir `/etc/mympd`, uid 91 |
| myMPD forced HTTPS with certificate errors | `ssl=true` + HSTS cached by browser | `ssl=false`; clear browser HSTS |
| M.A.L.P. refused connection | MPD bound to `127.0.0.1` | `bind_to_address "any"` |
| Share not mounted at boot | UCI `fstab` not honoured by `block mount`; `[ -d /mnt/music ]` true when unmounted | static `/etc/fstab` + `rc.local` checking `/proc/mounts` |
| `exception: No mixer` | client tried volume with `mixer_type "none"` | benign; use DAC knob |

---

## 5. Measured performance

### Audio path (10-minute playback test)

| Source | ALSA `hw_params` | CPU avg / max |
|---|---|---|
| 16/44.1 FLAC | 44100 Hz | 4.4 / 6.6 % |
| 24/96 FLAC | 96000 Hz | 5.9 / 9.1 % |
| 24/192 FLAC | 192000 Hz | 7.7 / 13.3 % |
| DSD64 (DoP) | 176400 Hz | 7.6 / 10.6 % |
| DSD128 (DoP) | 352800 Hz | 6.5 / 9.4 % |
| DSD256 (DoP) | 705600 Hz | 11.6 / 12.7 % |

Overall 5.85 % average CPU, 13.3 % peak, zero USB disconnects, no xruns.
**DSD256 over DoP works**; only DSD512 remains out of reach.

### Raw microbenchmarks

| Test | RT-AC88U |
|---|---|
| Integer MAC chain | 99.9 Mops/s (1 thread) / 199.8 (2) |
| Double dependent chain | 15.5 / 31.0 Mops/s |
| Memory read / write / copy | 0.43 / 1.84 / 0.36 GB/s |
| Memory latency 4 K→32 M | 6.6 → 277 ns |
| UBIFS write / read | 51.4 / 88.3 MB/s |
| tmpfs write / read | 307.4 / 396.2 MB/s |
| CIFS cold read | 13.0 MB/s (server-dependent) |
| CPU temp idle → after | 72.7 → 73.8 °C |

Full methodology and comparison guidance: [`BENCHMARKS.md`](BENCHMARKS.md).

---

## 6. Optimisation pass

| Change | Effect |
|---|---|
| Disabled `packet_steering`, `cron`, `gpio_switch` | removes a service that failed at every boot; no functional loss |
| myMPD `loglevel` 5→3, MPD `log_level "error"` | quieter logs, errors still recorded |
| CIFS `actimeo=60` | fewer SMB metadata round-trips |
| Kept USB-storage/fs stack | left intact; would only save ~1.9 MB on a 96 MB overlay |

Package removal was deliberately not pursued: overlay usage is ~1.2 MB of 96 MB,
so debloating would be cosmetic rather than necessary.

---

## 7. Deliverables

| Item | Reference |
|---|---|
| Image | `openwrt-25.12.6-bcm53xx-generic-asus_rt-ac88u-squashfs.trx` (13,369,344 bytes) |
| SHA256 | `612fe89737d871e51d78966e6ce174d88e77be41ab84bd003e87528de5a8a9fd` |
| Repository | <https://github.com/andrewr8712/rt-ac88u-openwrt-streamer> |
| Release | <https://github.com/andrewr8712/rt-ac88u-openwrt-streamer/releases/tag/v2.0> |
| Docs | `README.md`, `BENCHMARKS.md`, `WORKFLOW.md`, `docs/`, `CHANGELOG.md` |
| Setup script | `post-flash-setup.sh` (idempotent; tested on the device) |

---

## 8. Method & assumptions

- Usage read from DeepSeek Harness session transcripts, one record per model call
  (`inputTokens`, `cacheReadTokens`, `outputTokens`).
- **Model attribution:** records carry no model field. Calls before the recorded
  pro→flash switch (09:59 AWST) are attributed to pro; all later calls, and the
  follow-up session, to flash.
- **Peak/off-peak** determined per call from its UTC timestamp; 30 Oct 2026 is a
  Friday, not a Chinese public holiday.
- Search/fetch requests excluded (free until 1 Nov 2026).
- Prices as published on the date above and may change.

---

*Generated from recorded session usage and on-device measurements. Figures are
reproducible from the session transcript; rates are those published by DeepSeek
on 30 Oct 2026.*
