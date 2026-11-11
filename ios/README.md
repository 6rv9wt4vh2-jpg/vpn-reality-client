# iOS — VPN Reality (VLESS + Reality)

RU | EN

Приложение для iPhone: SwiftUI, общий Keychain для профилей и **Packet Tunnel**, который передаёт utun в **Xray-core** через официальный [XTLS/libXray](https://github.com/XTLS/libXray) `v26.11.9`. Исходящее соединение — **VLESS + Reality**, те же поля, что у десктопного клиента.

Это **не** готовый установленный VPN. На этой ветке нет подписи Apple, провижининга и проверенного прогона на устройстве. Пока xcframework не подключён, туннель **не** притворяется подключённым: `startTunnel` завершается ошибкой.

---

## English summary

The app stores profiles in the shared Keychain and starts a Network Extension packet tunnel. After the system creates the utun interface, the extension passes that file descriptor to Xray in `env["xray.tun.fd"]` and calls libXray `CGoInvoke` method `runXray`. Success is reported only when `getXrayState` says the core is running. Otherwise the tunnel fails closed.

libXray is MIT and wraps Xray-core (MPL-2.0). The binary is not committed. Download the pinned Apple build on a Mac. Do not link a second Go framework into the extension.

## What is implemented

| Piece | Behavior |
| --- | --- |
| Profile import | `vless://` and the desktop JSON shape, including Reality `pbk` / `sid` / SNI / `fp` / `spx` |
| Storage | Keychain item shared by app and extension. No plaintext `profiles.json` |
| Connect | `NETunnelProviderManager` save/load, then `startVPNTunnel` |
| Tunnel | IPv4/IPv6 routes, DNS, then Xray `tun` inbound |
| Core | `CGoInvoke` / `CGoFree` from libXray `v26.11.9` when `LIBXRAY_ENABLED` |
| Missing core | `TunnelFailure.coreNotLinked` — VPN does not stay up |
| Placeholder profiles | The repository example can be imported. Connect refuses it |
| Desktop app | Unchanged SOCKS/HTTP proxy on `127.0.0.1:10808` / `10809` |

## What this environment cannot prove

- Xcode build, signing, or an App Store / TestFlight upload
- Simulator or iPhone launch
- A real VLESS session or traffic through the tunnel
- That Apple will accept the packet-flow file-descriptor lookup (`socket.fileDescriptor` is not a public API; the Xray-documented utun scan is the fallback)

## Requirements before a phone can connect

1. Mac with **Xcode 15+** (iOS 16 deployment target).
2. **Paid** Apple Developer Program. A free team cannot ship a Packet Tunnel to a device.
3. Your own bundle IDs, App Group, and Keychain access group. Placeholders are `com.example.vpnreality`, `group.com.example.vpnreality`, and `$(AppIdentifierPrefix)com.example.vpnreality`. Change them together in:
   - both targets' Signing & Capabilities
   - `VpnReality.entitlements` and `VpnRealityTunnel.entitlements`
   - both `Info.plist` values `VPNKeychainAccessGroup`
   - `Shared/Constants.swift`
4. Official core, on the Mac:

```bash
chmod +x ios/VpnReality/ThirdParty/fetch-libxray.sh
ios/VpnReality/ThirdParty/fetch-libxray.sh
```

The script checks sha256 `7c58346709f1856782a48d8f9926fb815c8ad1bbaf9e5d9dec4ee0cd1f41ed6f` for `libxray-apple-cgo.zip` from release `v26.11.9`, unpacks `LibXray.xcframework`, and writes the gitignored `LibXray.local.xcconfig` that force-loads the static archive into **VpnRealityTunnel only**.

5. Open `ios/VpnReality/VpnReality.xcodeproj`, select your Team for **both** targets, and run the **VpnReality** scheme on a **physical iPhone**. The first connect shows the system VPN permission dialog.
6. Import **your** `vless://` link or JSON. The bundled example is a placeholder and connect will refuse it.

If the first device link fails on a missing system library, the undefined symbol is printed by `ld`. Add that framework in `ThirdParty/LibXray.local.xcconfig`. Do not add SwiftyXrayKit or another gomobile/cgo binary to the same extension process: Go allows one runtime per process.

## Architecture

```
VpnReality (SwiftUI)
    Keychain (profiles)  +  App Group (non-secret status only)
VpnRealityCore (import, validation, Xray JSON)
    NETunnelProviderManager
VpnRealityTunnel
    setTunnelNetworkSettings
    utun fd  →  env["xray.tun.fd"]
    libXray CGoInvoke runXray / stopXray
    Xray tun inbound → VLESS + Reality
```

The iOS document uses a `tun` inbound and literal private CIDRs, so the extension does not need `geoip.dat`. The desktop client still emits SOCKS/HTTP plus `geoip:private`. That split is deliberate: Xray 1.8.24 (the desktop pin) has no iOS TUN fd support; libXray `v26.11.9` does.

Server addresses that are IP literals are excluded from the tunnel routes. A hostname server is resolved by the extension; if that path loops on a particular iOS version, put the server IP in the profile.

## Checks without a Mac

From the repository root, with Swift on `PATH`:

```bash
bash scripts/verify.sh
```

That runs Python tests, `swift test` for `ios/VpnRealityCore`, builds both JSON shapes with `vpnreality-config`, and — when `libXray.so` / Xray 1.8.24 are available — asks the cores to **construct** the config (`testXray` or `xray run -test`). It does not call `runXray` and does not dial a server.

`vpnreality-config` prints a full Xray document, secrets included. Keep that output on the machine that already has the profile.

## License of the core

- This repository: MIT (`/LICENSE`)
- libXray: MIT — https://github.com/XTLS/libXray/blob/v26.11.9/LICENSE
- Xray-core inside that build: MPL-2.0 — https://github.com/XTLS/Xray-core/blob/main/LICENSE

Linking them from this MIT app is intentional. If you distribute a binary, keep those license notices with the app and do not relicense the Xray sources.

## Desktop client

Python SOCKS/HTTP proxy: repository root [README.md](../README.md). Its commands and generated proxy JSON are unchanged.
