# Patches

Applied to upstream sources before building:

| Patch | Target | Why |
|---|---|---|
| `mympd-26.1.1-remove-werror.patch` | myMPD 26.1.1 `CMakeLists.txt` | `-Werror` breaks the vendored mongoose build with newer compilers |

MPD needs no source patch: DSD support is enabled with `-Ddsd=true` (see
`build/mpd-cross.txt` and `docs/BUILD.md`).

Apply with:

```sh
cd myMPD-26.1.1
patch -p1 < ../patches/mympd-26.1.1-remove-werror.patch
```
