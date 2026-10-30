# RT-AC88U OpenWrt Music Streamer — Project Report

**Date:** 30 October 2026 · **Status:** Delivered · **Session:** `session-ae0964a9`

---

## Executive summary

| Metric | Value |
|---|---|
| Wall-clock time | **2 h 44 m** (09:46 → 12:30 AWST) |
| Model calls | **314** |
| Total tokens | **78,135,661** |
| Cache hit rate | **99.66 %** |
| Total API cost | **$0.93 USD** |
| Final image | 14 MB, SHA256 `532262ce…1d5b029` |
| Deliverables | flashable image, GitHub repo, v1.0 release |

---

## 1. Token usage

| Model | Calls | Input (cache miss) | Input (cache hit) | Output | Total |
|---|---:|---:|---:|---:|---:|
| `deepseek-v4-pro` | 6 | 35,274 | 134,528 | 17,781 | 187,583 |
| `deepseek-flash` | 308 | 228,528 | 77,460,352 | 259,198 | 77,948,078 |
| **Total** | **314** | **263,802** | **77,594,880** | **276,979** | **78,135,661** |

- Cache hit ratio: **99.66 %** of all prompt tokens
- Average per call: ~248,840 tokens, ~882 output tokens
- Cache writes: 0
- Search/fetch tool requests: 11 (free until 1 Nov 2026 — see notes)

The large total is expected for an agentic session: each of the 314 calls re-sends the
conversation context, and almost all of that is served from the prompt cache.

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
| `deepseek-flash` | 308 | 288 / 20 | **$0.8106** |
| — of which peak | | | $0.7768 |
| — of which off-peak | | | $0.0338 |
| **Total** | **314** | **294 / 20** | **$0.9335** |

**Rounded total: $0.93 USD** — average $0.0030 per model call.

Notes:

- The session ran 09:46–12:00 AWST = 01:46–04:00 UTC, inside the peak window on a
  Friday; the last 20 calls after 12:00 AWST were billed off-peak.
- The 11 search/fetch requests are currently free; per-request billing starts
  1 Nov 2026.
- Costs are computed per call from recorded usage, not from an aggregate estimate.

---

## 3. Performance summary

### Milestones

| Time (AWST) | Milestone |
|---|---|
| 09:46 | Session start; feasibility research |
| 10:07 | First image built (17 MB, rejected: PulseAudio bloat) |
| 10:08 | Lean 11 MB image (`mpd-mini`) |
| 10:55 | DSD-enabled `mpd` compiled |
| 10:58 | DSD image built |
| 11:08 | DHCP-client LAN variant |
| 11:38 | myMPD compiled |
| 11:41 | Final 14 MB image (LuCI + myMPD + SMB) |
| 12:01 | GitHub release v1.0 published |
| 12:30 | Report generated |

### Build iterations

Six image builds (five configurations) were required to converge:

1. `mpd-full` baseline — 17 MB, rejected after dependency audit
2. `mpd-mini` — 11 MB, PulseAudio/BlueZ/Avahi removed
3. DSD-enabled `mpd` — 11 MB
4. Rebuild with host RPATH stripped — 11 MB
5. DHCP-client LAN default — 11 MB
6. LuCI + myMPD + SMB/CIFS — **14 MB (final)**

### Verification performed

- SHA256 checks at every image stage
- TRX header (`HDR0`) validation
- `NEEDED` library cross-check against the image rootfs (all resolved)
- RPATH stripped from the custom binaries
- Rootfs binary hash equality with the overlay
- GitHub release asset digest matched to the image hash

### Expected device performance

Not measured on hardware; based on platform specs:

- Dual Cortex-A9 @ 1.4 GHz + 512 MB RAM — ample for MPD, upmpdcli, myMPD, LuCI
- FLAC and DoP DSD decode comfortably real-time
- Bit-perfect PCM path (`hw:0,0`, no resampling, no volume processing)
- Wired Ethernet + SMB only (BCM4366 Wi-Fi not usable under OpenWrt)

---

## 4. Method & assumptions

- Usage was read from DeepSeek Harness session transcripts
  (`~/.dsh/sessions/.../session.v4.jsonl.zstd`), one record per model call with
  `inputTokens`, `cacheReadTokens`, `outputTokens`.
- **Model attribution:** token records carry no model field. Calls before the
  recorded `deepseek-v4-pro → deepseek-flash` switch (09:59 AWST) are attributed to
  pro; all later calls, and the follow-up session, to flash. Pro's 6-call share is
  consistent with the switch timing.
- **Peak/off-peak:** determined per call from its UTC timestamp using the published
  windows; 30 Oct 2026 is a Friday and not a Chinese public holiday.
- Search/fetch requests are excluded from token cost (currently free).
- Prices are as published on the date above and may change.

---

## 5. Deliverables

| Item | Reference |
|---|---|
| Image | `openwrt-24.10.8-bcm53xx-generic-asus_rt-ac88u-squashfs.trx` (14,024,704 bytes) |
| SHA256 | `532262ce38b0f6b5f0d5fe6d77015778a007ad926a165357e986df7221d5b029` |
| Repository | <https://github.com/andrewr8712/rt-ac88u-openwrt-streamer> |
| Release | <https://github.com/andrewr8712/rt-ac88u-openwrt-streamer/releases/tag/v1.0> |
| Documentation | `README.md`, `docs/BUILD.md`, `docs/HARDWARE.md`, `docs/TROUBLESHOOTING.md`, `CHANGELOG.md` |

---

*Generated from recorded session usage. Figures are reproducible from the session
transcript; rates are those published by DeepSeek on 30 Oct 2026.*
