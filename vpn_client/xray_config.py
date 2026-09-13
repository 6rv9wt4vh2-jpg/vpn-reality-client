"""Generate xray-core JSON from a VlessProfile."""

from __future__ import annotations

from typing import Any

from vpn_client.models import VlessProfile
from vpn_client.paths import DEFAULT_HTTP_PORT, DEFAULT_SOCKS_PORT


def build_xray_config(profile: VlessProfile) -> dict[str, Any]:
    """Build a minimal client config: SOCKS(+HTTP) inbounds → VLESS Reality outbound."""
    socks_port = profile.socks_port or DEFAULT_SOCKS_PORT
    http_port = profile.http_port

    inbounds: list[dict[str, Any]] = [
        {
            "tag": "socks-in",
            "port": socks_port,
            "listen": "127.0.0.1",
            "protocol": "socks",
            "settings": {"udp": True, "auth": "noauth"},
            "sniffing": {
                "enabled": True,
                "destOverride": ["http", "tls", "quic"],
            },
        }
    ]
    if http_port:
        inbounds.append(
            {
                "tag": "http-in",
                "port": http_port or DEFAULT_HTTP_PORT,
                "listen": "127.0.0.1",
                "protocol": "http",
                "settings": {"allowTransparent": False},
            }
        )

    reality = profile.reality
    stream: dict[str, Any] = {
        "network": profile.network,
        "security": "reality",
        "realitySettings": {
            "show": False,
            "fingerprint": reality.fingerprint,
            "serverName": profile.primary_sni(),
            "publicKey": reality.public_key,
            "shortId": reality.short_id,
            "spiderX": reality.spider_x,
        },
    }

    outbound: dict[str, Any] = {
        "tag": "proxy",
        "protocol": "vless",
        "settings": {
            "vnext": [
                {
                    "address": profile.address,
                    "port": profile.port,
                    "users": [
                        {
                            "id": profile.uuid,
                            "encryption": profile.encryption,
                            "flow": profile.flow,
                        }
                    ],
                }
            ]
        },
        "streamSettings": stream,
    }

    return {
        "log": {"loglevel": "warning"},
        "inbounds": inbounds,
        "outbounds": [
            outbound,
            {"tag": "direct", "protocol": "freedom", "settings": {}},
            {"tag": "block", "protocol": "blackhole", "settings": {}},
        ],
        "routing": {
            "domainStrategy": "AsIs",
            "rules": [
                {
                    "type": "field",
                    "outboundTag": "direct",
                    "ip": ["geoip:private"],
                }
            ],
        },
    }


def write_xray_config(profile: VlessProfile, path) -> dict[str, Any]:  # noqa: ANN001
    import json
    from pathlib import Path

    cfg = build_xray_config(profile)
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return cfg
