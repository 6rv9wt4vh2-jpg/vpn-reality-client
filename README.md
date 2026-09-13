# vpn-reality-client

Лёгкий **MVP** десктоп-клиента для **VLESS + Reality** на базе [Xray-core](https://github.com/XTLS/Xray-core).  
Пользователь указывает **свой** сервер; в репозитории только плейсхолдеры.

> **Важно:** клиент поднимает **локальные SOCKS5/HTTP прокси**, а не системный TUN/VPN.  
> Проект **не гарантирует** обход DPI или блокировок (в т.ч. в РФ). Эффективность зависит от сервера, SNI, версии ядра и сети.

---

## English summary

Python CLI + optional local FastAPI dashboard. Profiles store Reality fields (`publicKey`, `shortId`, `serverNames`, `fingerprint`, `spiderX`, optional `dest`). The app generates xray JSON, starts/stops the core, and listens on `127.0.0.1:10808` (SOCKS5) and optionally `10809` (HTTP).

## Stack

| Piece | Choice |
|--------|--------|
| Language | Python 3.10+ |
| CLI | Typer + Rich |
| UI | FastAPI + static HTML (`vpn-reality ui`) |
| Core | Official **Xray-core** binary (downloaded to `./bin`) |

## Requirements

- Linux (smoke-tested), macOS/Windows possible with your own xray binary
- Python 3.10+
- Network access to download Xray releases (first time)

## Install

```bash
git clone https://github.com/6rv9wt4vh2-jpg/vpn-reality-client.git
cd vpn-reality-client
python3 -m venv .venv
source .venv/bin/activate
pip install -e .

# Download official Xray-core into ./bin
vpn-reality install-xray
# or: python -m vpn_client.install_xray
```

Если авто-загрузка недоступна, скачайте релиз вручную с  
https://github.com/XTLS/Xray-core/releases  
и положите бинарник `xray` в `./bin/` (chmod +x) или в `PATH`.

## Quick start

```bash
# Import placeholder example (replace fields with YOUR server first)
vpn-reality import examples/client-reality.json

# Or import a vless:// link
vpn-reality import 'vless://…'

# List / generate config / connect
vpn-reality list
vpn-reality show-config --write
vpn-reality connect
vpn-reality status

# Point browser/app to:
#   SOCKS5  127.0.0.1:10808
#   HTTP    127.0.0.1:10809

vpn-reality disconnect
```

### Web UI

```bash
vpn-reality ui
# open http://127.0.0.1:8787
```

### Add via flags

```bash
vpn-reality add \
  --name my-server \
  --address YOUR_SERVER \
  --port 443 \
  --uuid 00000000-0000-4000-8000-000000000000 \
  --pbk REPLACE_PUBLIC_KEY \
  --sid abcd1234 \
  --sni www.cloudflare.com \
  --fp chrome
```

## Reality fields (first-class)

| Field | CLI / JSON | Meaning |
|--------|------------|---------|
| `public_key` | `--pbk` / `pbk` | Server Reality public key |
| `short_id` | `--sid` / `sid` | Reality shortId |
| `server_names` | `--sni` | SNI list |
| `fingerprint` | `--fp` | uTLS fingerprint (e.g. chrome) |
| `spider_x` | `--spx` | spiderX path |
| `dest` | optional | Usually server-side; kept for import parity |

See `examples/client-reality.json` and `docs/server-reality-setup.md`.

## Project layout

```
vpn_client/          # Python package (models, xray JSON, process, CLI, web)
web/static/          # Local dashboard
examples/            # Placeholder client config + URI
docs/                # Server Reality checklist
bin/                 # Downloaded xray (gitignored)
data/                # profiles + runtime config (gitignored contents)
```

## Limitations (MVP)

- No system-wide TUN/routing — proxy only
- No auto system proxy configuration
- No tray/native GUI (web UI is local-only)
- No traffic split UI beyond basic private-IP direct rule
- Smoke test without a real Reality server only verifies binary start + config generation
- Does **not** claim DPI bypass success in any jurisdiction

## License

MIT — see [LICENSE](LICENSE).
