# iOS — VPN Reality (VLESS + Reality)

RU | EN

Каркас **Xcode** приложения: SwiftUI + Network Extension (Packet Tunnel).  
Собирается на **Mac** (Xcode 15+). Этот репозиторий **не** содержит готовый App Store бинарник и **не** включает предсобранный Xray/sing-box.

> **Честно:** без (1) связанного LibXray / SwiftyXrayKit / sing-box Libbox, (2) платного Apple Developer Program, (3) provisioning для Network Extension — VPN на телефоне **не** будет проксировать трафик. Сейчас туннель поднимает utun и пишет конфиг, но ядро — **stub**.

---

## English summary

SwiftUI profile list (RU UI), JSON/`vless://` import with first-class Reality fields, App Group shared store, `NETunnelProviderManager` connect/disconnect, and a Packet Tunnel Provider that generates xray-core JSON (parity with the Python desktop client). Core embedding is documented under `VpnReality/ThirdParty/` — link on a Mac.

## Requirements

| Item | Notes |
|------|--------|
| Mac + **Xcode 15+** | Cannot build iOS Network Extension on Linux |
| iOS **16+** deployment | Set in project |
| **Paid** Apple Developer | Free accounts cannot use Packet Tunnel on device |
| Physical iPhone/iPad | Simulator can compile UI; real VPN needs device |
| LibXray or sing-box | Optional until you want real traffic — see ThirdParty |

## Open & sign (Mac)

1. Clone the repo and open:
   ```bash
   open ios/VpnReality/VpnReality.xcodeproj
   ```
2. Select the **VpnReality** project → both targets (**VpnReality**, **VpnRealityTunnel**):
   - **Signing & Capabilities** → your **Team**
   - Change bundle IDs from placeholders:
     - App: `com.example.vpnreality` → yours
     - Tunnel: `com.example.vpnreality.tunnel` → `*.tunnel` under the same prefix
3. Add capability **App Groups** on **both** targets with the **same** group ID, e.g. `group.YOURTEAM.vpnreality`.
4. Ensure **Network Extensions** → Packet Tunnel Provider is present (entitlements templates already list `packet-tunnel-provider`).
5. Update matching strings in code:
   - `Shared/Constants.swift` → `appGroupID`, `appBundleID`, `tunnelProviderBundleID`
   - `VpnReality.entitlements` and `VpnRealityTunnel.entitlements`
6. Scheme **VpnReality** → run on a **device**.

First connect triggers the system VPN permission dialog.

## Link a real core (required for traffic)

See [VpnReality/ThirdParty/README.md](VpnReality/ThirdParty/README.md).

Short path (recommended):

1. Xcode → **File → Add Package Dependencies** → `https://github.com/dima-u/SwiftyXrayKit`
2. Add the package to **VpnRealityTunnel**
3. In `PacketTunnelProvider.startCoreIfAvailable`, use `XrayBridge(packetFlow:)` after network settings (TODOs in source)
4. Or run `ThirdParty/fetch-libxray.sh` on macOS and link `LibXray.xcframework`

Until then the provider logs: *No Xray/sing-box core linked — tunnel stub only.*

## Architecture

```
VpnReality (SwiftUI App)
    ↕ App Group (profiles.json, runtime-config.json)
Shared/  (models, importer, xray JSON builder, store)
    ↕
VpnRealityTunnel (NEPacketTunnelProvider)
    → [stub | LibXray / SwiftyXrayKit / Libbox]
```

### Reality fields (first-class)

`address`, `port`, `uuid`, `flow`, `public_key` / pbk, `short_id` / sid, `server_names` / SNI, `fingerprint` / fp, `spider_x` / spx, optional `dest` — same as desktop `examples/client-reality.json`.

Import UI includes a pasteable example matching that file.

## Project layout

```
ios/
  README.md                          ← this file
  VpnReality/
    VpnReality.xcodeproj/
    VpnReality/                      ← app target (SwiftUI)
    VpnRealityTunnel/                ← packet-tunnel appex
    Shared/                          ← compiled into both targets
    ThirdParty/                      ← docs + fetch script (no binary)
```

## Limitations

- Not an App Store submission guide (privacy nutrition, review VPN justification, account holder legal entity, etc. are on you)
- No TestFlight / distribution automation in this MVP
- Stub tunnel ≠ working proxy
- No claim of DPI bypass in any jurisdiction
- Placeholders only — never commit production keys

## Desktop client

Python MVP (SOCKS/HTTP local proxy): see repository root [README.md](../README.md).
