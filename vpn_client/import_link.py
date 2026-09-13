"""Import VLESS Reality share links and JSON profiles."""

from __future__ import annotations

import json
import re
from urllib.parse import parse_qs, unquote, urlparse

from vpn_client.models import RealitySettings, VlessProfile


def parse_vless_uri(uri: str) -> VlessProfile:
    """
    Parse vless://UUID@host:port?encryption=none&flow=...&security=reality&sni=...&fp=...&pbk=...&sid=...&spx=...#name
    """
    uri = uri.strip()
    if not uri.lower().startswith("vless://"):
        raise ValueError("expected vless:// URI")

    parsed = urlparse(uri)
    uuid = parsed.username or ""
    host = parsed.hostname or ""
    port = parsed.port or 443
    if not uuid or not host:
        raise ValueError("vless URI missing uuid or host")

    q = {k: v[0] for k, v in parse_qs(parsed.query).items()}
    name = unquote(parsed.fragment) if parsed.fragment else f"{host}:{port}"

    sni = q.get("sni") or q.get("serverName") or "www.cloudflare.com"
    server_names = [s.strip() for s in sni.split(",") if s.strip()]
    pbk = q.get("pbk") or q.get("publicKey") or ""
    if not pbk:
        raise ValueError("Reality public key (pbk) required")

    reality = RealitySettings(
        public_key=pbk,
        short_id=q.get("sid") or q.get("shortId") or "",
        server_names=server_names,
        fingerprint=q.get("fp") or q.get("fingerprint") or "chrome",
        spider_x=unquote(q.get("spx") or q.get("spiderX") or "/"),
        dest=q.get("dest"),
    )

    return VlessProfile(
        name=name,
        address=host,
        port=int(port),
        uuid=uuid,
        flow=q.get("flow") or "xtls-rprx-vision",
        reality=reality,
    )


def parse_profile_json(text: str) -> VlessProfile:
    """Parse our profile JSON or a minimal xray-like outbound snippet."""
    data = json.loads(text)
    if "reality" in data or ("address" in data and "uuid" in data):
        return VlessProfile.model_validate(data)

    # Minimal xray outbound compatibility
    if data.get("protocol") == "vless" or "vnext" in data.get("settings", {}):
        vnext = data["settings"]["vnext"][0]
        user = vnext["users"][0]
        rs = data.get("streamSettings", {}).get("realitySettings", {})
        sni = rs.get("serverName") or "www.cloudflare.com"
        return VlessProfile(
            name=data.get("tag") or f"{vnext['address']}:{vnext['port']}",
            address=vnext["address"],
            port=int(vnext["port"]),
            uuid=user["id"],
            flow=user.get("flow") or "xtls-rprx-vision",
            reality=RealitySettings(
                public_key=rs.get("publicKey", ""),
                short_id=rs.get("shortId", ""),
                server_names=[sni],
                fingerprint=rs.get("fingerprint", "chrome"),
                spider_x=rs.get("spiderX", "/"),
            ),
        )

    raise ValueError("unrecognized profile JSON")


def import_any(text: str) -> VlessProfile:
    text = text.strip()
    if text.lower().startswith("vless://"):
        return parse_vless_uri(text)
    if text.startswith("{"):
        return parse_profile_json(text)
    # try extract vless from clipboard paste with noise
    m = re.search(r"vless://\S+", text, re.I)
    if m:
        return parse_vless_uri(m.group(0).rstrip(")'\",\n"))
    raise ValueError("provide a vless:// link or profile JSON")
