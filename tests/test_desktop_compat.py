"""Lock the desktop VLESS + Reality config and import behavior."""

from __future__ import annotations

import json
from pathlib import Path

from vpn_client.import_link import import_any
from vpn_client.xray_config import build_xray_config

ROOT = Path(__file__).resolve().parents[1]
EXAMPLE = ROOT / "examples" / "client-reality.json"
URI = (
    "vless://00000000-0000-4000-8000-000000000000@YOUR_SERVER_IP_OR_DOMAIN:443"
    "?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.cloudflare.com"
    "&fp=chrome&pbk=sCMyd0MxQEessoya6gphVLM9lOX9-5tuWBMRlskeuwA&sid=abcd1234"
    "&spx=%2F#example-reality"
)


def test_example_json_import_and_proxy_config():
    profile = import_any(EXAMPLE.read_text(encoding="utf-8"))
    cfg = build_xray_config(profile)

    assert cfg["log"] == {"loglevel": "warning"}
    assert [item["protocol"] for item in cfg["inbounds"]] == ["socks", "http"]
    assert cfg["inbounds"][0]["port"] == 10808
    assert cfg["inbounds"][0]["listen"] == "127.0.0.1"
    assert cfg["inbounds"][0]["settings"] == {"udp": True, "auth": "noauth"}
    assert cfg["inbounds"][1]["port"] == 10809
    assert cfg["inbounds"][1]["settings"] == {"allowTransparent": False}

    proxy = cfg["outbounds"][0]
    assert proxy["protocol"] == "vless"
    user = proxy["settings"]["vnext"][0]["users"][0]
    assert user["encryption"] == "none"
    assert user["flow"] == "xtls-rprx-vision"
    reality = proxy["streamSettings"]["realitySettings"]
    assert reality["show"] is False
    assert reality["serverName"] == "www.cloudflare.com"
    assert reality["fingerprint"] == "chrome"
    assert reality["spiderX"] == "/"
    assert reality["shortId"] == "abcd1234"
    assert cfg["routing"]["domainStrategy"] == "AsIs"
    assert cfg["routing"]["rules"][0]["ip"] == ["geoip:private"]
    assert cfg["outbounds"][1]["protocol"] == "freedom"
    assert cfg["outbounds"][2]["protocol"] == "blackhole"
    assert "env" not in cfg


def test_vless_uri_matches_example_fields():
    from_uri = import_any(URI)
    from_json = import_any(EXAMPLE.read_text(encoding="utf-8"))
    # urllib lowercases URI hostnames. JSON import keeps the original spelling.
    assert from_uri.address == "your_server_ip_or_domain"
    assert from_json.address == "YOUR_SERVER_IP_OR_DOMAIN"
    assert from_uri.port == from_json.port
    assert from_uri.uuid == from_json.uuid
    assert from_uri.reality.public_key == from_json.reality.public_key
    assert from_uri.reality.short_id == from_json.reality.short_id
    assert from_uri.reality.spider_x == "/"
    assert from_uri.name == "example-reality"


def test_config_is_json_serializable():
    profile = import_any(EXAMPLE.read_text(encoding="utf-8"))
    json.dumps(build_xray_config(profile))
