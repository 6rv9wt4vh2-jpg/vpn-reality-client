"""Static checks that the iOS packet tunnel fails closed and calls libXray."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TUNNEL = ROOT / "ios" / "VpnReality" / "VpnRealityTunnel"
APP = ROOT / "ios" / "VpnReality" / "VpnReality"


def test_provider_fails_closed_and_starts_libxray():
    source = (TUNNEL / "PacketTunnelProvider.swift").read_text(encoding="utf-8")
    assert "StubCoreHandle" not in source
    assert "LibXrayRuntime.run" in source
    assert "coreNotLinked" in source
    assert source.count("completionHandler(nil)") == 1
    assert "runtime-config.json" not in source
    assert "print(" not in source


def test_runtime_calls_official_invoke_symbols():
    source = (TUNNEL / "LibXrayRuntime.swift").read_text(encoding="utf-8")
    assert "CGoInvoke" in source
    assert "CGoFree" in source
    assert "LIBXRAY_ENABLED" in source
    assert "coreNotLinked" in source


def test_tunnel_config_uses_documented_fd_env():
    builder = (
        ROOT / "ios" / "VpnRealityCore" / "Sources" / "VpnRealityCore" / "XrayConfigBuilder.swift"
    ).read_text(encoding="utf-8")
    assert '"xray.tun.fd"' in builder
    assert '"protocol": "tun"' in builder
    assert "geoip:private" in builder  # desktop-parity proxy config only
    assert "autoSystemRoutingTable" not in builder


def test_entitlements_and_extension_point():
    for name in ("VpnReality.entitlements", "VpnRealityTunnel.entitlements"):
        if name.startswith("VpnRealityTunnel"):
            text = (TUNNEL / name).read_text(encoding="utf-8")
        else:
            text = (APP / name).read_text(encoding="utf-8")
        assert "packet-tunnel-provider" in text
        assert "com.apple.security.application-groups" in text
        assert "keychain-access-groups" in text
        assert "group.com.example.vpnreality" in text
    info = (TUNNEL / "Info.plist").read_text(encoding="utf-8")
    assert "com.apple.networkextension.packet-tunnel" in info
    assert "VPNKeychainAccessGroup" in info


def test_fetch_script_pins_release_checksum():
    script = (ROOT / "ios" / "VpnReality" / "ThirdParty" / "fetch-libxray.sh").read_text(encoding="utf-8")
    assert "v26.11.9" in script
    assert "7c58346709f1856782a48d8f9926fb815c8ad1bbaf9e5d9dec4ee0cd1f41ed6f" in script
    assert "libxray-apple-cgo.zip" in script


def test_profiles_are_not_written_as_plaintext_json_by_the_app():
    vault = (APP / "Services" / "ProfileVault.swift").read_text(encoding="utf-8")
    assert "kSecClassGenericPassword" in vault
    assert "profiles.json" not in vault
    app_sources = "\n".join(path.read_text(encoding="utf-8") for path in APP.rglob("*.swift"))
    assert "writeRuntimeConfigJSON" not in app_sources
