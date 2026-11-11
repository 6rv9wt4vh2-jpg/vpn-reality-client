# ThirdParty — XTLS/libXray

The Apple binary is not in git. The packet tunnel calls the C API that ships in official libXray `v26.11.9`:

```c
char* CGoInvoke(char* requestJSON);
void CGoFree(char* value);
```

`requestJSON` is API version 3. The methods used here are `runXray`, `stopXray`, `getXrayState`, and `xrayVersion`. The Xray document puts the Network Extension utun descriptor in the config root:

```json
"env": { "xray.tun.fd": "<fd>" }
```

with a `tun` inbound. That is the iOS path documented by Xray-core (`proxy/tun`) and libXray (the old `SetTunFd` helper was removed).

## Pin

| | |
| --- | --- |
| Release | `v26.11.9` |
| Asset | `libxray-apple-cgo.zip` |
| sha256 | `7c58346709f1856782a48d8f9926fb815c8ad1bbaf9e5d9dec4ee0cd1f41ed6f` |
| Layout | static `libXray.a` plus `Headers/libXray.h` and `Headers/module.modulemap` |

On a Mac:

```bash
./fetch-libxray.sh
```

The script writes `LibXray.local.xcconfig` (gitignored). `Config/Tunnel.xcconfig` includes it. Until that file exists, the extension compiles without `LIBXRAY_ENABLED` and `startTunnel` returns `coreNotLinked`.

Link the archive only into **VpnRealityTunnel**. The app process must not load a second Go runtime.

## Linux check of the same release

`libxray-linux-x64.zip` from the same tag exports the same `CGoInvoke`. `scripts/verify-libxray-config.py` can pass a generated document to `testXray`. That constructs an Xray instance and closes it. It is not a packet tunnel and it does not connect to a server.

## Why not another core

- Xray-core is the VLESS + Reality implementation this desktop client already uses.
- sing-box's Apple library is GPL-3.0, which this MIT repository does not vendor.
- A second Go framework (including SwiftyXrayKit's own libXray build) in the same extension crashes Go at startup. Do not add one next to this xcframework.

## Licenses

libXray is MIT. The linked Xray-core code is MPL-2.0. Both notices have to travel with a distributed binary. See `ios/README.md`.
