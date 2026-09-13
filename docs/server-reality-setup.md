# Server-side Reality setup (high level)

This client expects a **VLESS + Reality** inbound on **your own** server.  
This document is a high-level checklist — not a full hardened production guide.

> **Disclaimer:** You are responsible for complying with local law and the policies of any network you use. This project does **not** claim to always bypass DPI or national blocks (including in Russia).

## 1. Install Xray-core on the server

Use an official release from [XTLS/Xray-core](https://github.com/XTLS/Xray-core/releases).  
Prefer a recent stable tag; keep client and server versions reasonably close.

## 2. Generate Reality key pair

On a machine with `xray`:

```bash
xray x25519
```

You get a **PrivateKey** (server only) and **PublicKey** (give to clients as `pbk`).  
Generate one or more **shortIds** (hex, typically 2–16 bytes), e.g.:

```bash
openssl rand -hex 8
```

## 3. Choose SNI / dest carefully

Reality masquerades TLS as a legitimate destination (`dest` / `serverNames`):

- Prefer popular HTTPS sites that support **TLS 1.3** and are reachable from your server and clients.
- Classic examples used in docs: CDN / large vendor frontends (e.g. `www.cloudflare.com`, `www.microsoft.com`) — **verify** they still work as Reality targets for your region and Xray version.
- `serverNames` (SNI) on the client must match what the server accepts (`serverNames` in Reality settings).
- Avoid pointing `dest` at your own unused domain unless you understand the handshake implications.

## 4. Sample inbound sketch (placeholders)

Minimal conceptual inbound (fill in your own values; structure may vary slightly by Xray version):

```json
{
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "00000000-0000-4000-8000-000000000000",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.cloudflare.com:443",
          "xver": 0,
          "serverNames": ["www.cloudflare.com", "www.microsoft.com"],
          "privateKey": "REPLACE_SERVER_PRIVATE_KEY",
          "shortIds": ["", "abcd1234"]
        }
      }
    }
  ]
}
```

Give the client:

| Field | Source |
|--------|--------|
| address / port | your VPS |
| uuid | client `id` |
| flow | usually `xtls-rprx-vision` |
| pbk / publicKey | from `xray x25519` |
| sid / shortId | one of `shortIds` |
| sni / serverNames | one of `serverNames` |
| fp / fingerprint | e.g. `chrome` |
| spx / spiderX | often `/` |

## 5. Firewall & TLS port

- Open TCP **443** (or your chosen port) to the world.
- Do not run another service that conflicts on the same IP:port unless you know what you are doing.
- Keep the server time accurate (NTP) — TLS is sensitive to clock skew.

## 6. Hand off to this client

Import a `vless://…` share link or `examples/client-reality.json` filled with **your** values:

```bash
vpn-reality import examples/client-reality.json
vpn-reality connect
```

Point browser/app SOCKS5 to `127.0.0.1:10808` (or HTTP `10809`).

## 7. Ops tips

- Rotate UUID / shortId if a profile leaks.
- Never commit private keys or live `pbk` of production servers into public repos.
- Test with `curl --socks5-hostname 127.0.0.1:10808 https://ifconfig.co` after connect.
- If handshakes fail, check SNI mismatch, wrong public key, blocked port, or outdated Xray.
