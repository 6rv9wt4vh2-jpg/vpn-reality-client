# ThirdParty — LibXray / sing-box on Apple platforms

This folder is intentionally **empty of binaries**. Prebuilt `*.xcframework` files are large,
platform-specific, and not reliably downloadable from this Linux CI/box. Link a core on a **Mac**.

## Recommended paths

### A) SwiftyXrayKit + libXray-apple (preferred for Xray)

Used by several open-source iOS clients. Wraps a patched Xray TUN inbound that works with
`NEPacketTunnelFlow` (iOS sandbox forbids some socket types).

1. On a Mac with Xcode 15+:
   ```bash
   # Option 1 — Swift Package Manager
   # File → Add Package Dependencies →
   # https://github.com/dima-u/SwiftyXrayKit
   ```
2. Or place `LibXray.xcframework` / vendor SPM under:
   ```
   ios/VpnReality/ThirdParty/LibXray.xcframework
   ```
3. In `PacketTunnelProvider.startCoreIfAvailable`:
   - `import SwiftyXrayKit`
   - After `setTunnelNetworkSettings`, create `XrayBridge(packetFlow:)` and `start(config:dataDir:finalConfigPath:)`
   - Keep `bridge` in `coreHandle` and `stop()` on tunnel stop
4. Ship `geoip.dat` / `geosite.dat` in the extension bundle or App Group if your config uses `geoip:` rules.

Upstream references:
- https://github.com/XTLS/libXray (gomobile / cgo → `LibXray.xcframework`)
- https://github.com/dima-u/SwiftyXrayKit
- https://github.com/dima-u/libXray-apple

### B) Official XTLS/libXray build

```bash
# On macOS with Go + gomobile + iOS SDK:
./ThirdParty/fetch-libxray.sh   # prints steps; does not download on Linux
```

Then drag `LibXray.xcframework` into the **VpnRealityTunnel** target
(Embed & Sign / Link Binary). Import module `LibXray` and call the Run/Stop C APIs
exported by your build (names differ slightly by libXray version).

### C) sing-box Libbox

Official Apple clients (SFI) use `Libbox.xcframework` + `PlatformInterface.OpenTun`.

1. Build Libbox for Apple from sing-box (`buildApple` / libbox docs).
2. Implement platform callbacks; start service from the packet tunnel.
3. Convert our `VlessProfile` → sing-box JSON (separate mapper; not included yet).

Docs: https://sing-box.sagernet.org/clients/apple/

## What already works without a core

| Piece | Status |
|--------|--------|
| SwiftUI profile list / RU UI | ✅ |
| Import JSON + `vless://` | ✅ |
| Reality fields (pbk, sid, SNI, fp, spx, flow, …) | ✅ |
| Generate xray JSON (desktop parity) | ✅ |
| App Group shared store | ✅ (needs real App Group ID) |
| `NETunnelProviderManager` connect UI | ✅ |
| Packet tunnel settings | ✅ stub |
| Actual VLESS+Reality traffic | ❌ until core linked + paid team + device |

## Script

`fetch-libxray.sh` documents Mac-side build/fetch commands and verifies the
`ThirdParty` layout. It exits non-zero on Linux with instructions (by design).
