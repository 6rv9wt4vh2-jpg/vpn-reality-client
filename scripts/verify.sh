#!/usr/bin/env bash
# Checks that can run without Xcode, a signing identity, or a device.
# Does not connect to a VPN server and does not call runXray.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 -m pip install -q -e ".[dev]"
python3 -m pytest -q tests

if command -v swift >/dev/null 2>&1; then
  (cd ios/VpnRealityCore && swift test)
else
  echo "swift is not on PATH; skipping ios/VpnRealityCore tests" >&2
  exit 1
fi

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
swift run --package-path ios/VpnRealityCore vpnreality-config tunnel --tun-fd 7 \
  examples/client-reality.json > "${OUT}/tunnel.json"
swift run --package-path ios/VpnRealityCore vpnreality-config proxy \
  examples/client-reality.json > "${OUT}/proxy.json"

python3 - <<PY
import json
tunnel = json.load(open("${OUT}/tunnel.json"))
proxy = json.load(open("${OUT}/proxy.json"))
assert tunnel["inbounds"][0]["protocol"] == "tun"
assert tunnel["env"]["xray.tun.fd"] == "7"
assert "geoip:" not in json.dumps(tunnel)
assert proxy["inbounds"][0]["protocol"] == "socks"
assert proxy["routing"]["rules"][0]["ip"] == ["geoip:private"]
print("swift config shapes ok")
PY

LIB="${VPN_LIBXRAY_SO:-}"
if [[ -z "${LIB}" && -f /tmp/libxray-linux/libxray-linux-x64/libXray.so ]]; then
  LIB=/tmp/libxray-linux/libxray-linux-x64/libXray.so
fi
XRAY1824="${XRAY_1824_BIN:-}"
if [[ -z "${XRAY1824}" && -x /tmp/xray-1824/xray ]]; then
  XRAY1824=/tmp/xray-1824/xray
fi
if [[ -z "${XRAY_LOCATION_ASSET:-}" && -n "${XRAY1824}" && -f "$(dirname "${XRAY1824}")/geoip.dat" ]]; then
  export XRAY_LOCATION_ASSET="$(dirname "${XRAY1824}")"
fi
if [[ -n "${LIB}" ]]; then
  python3 scripts/verify-libxray-config.py --lib "${LIB}" --config "${OUT}/tunnel.json"
  if [[ -n "${XRAY_LOCATION_ASSET:-}" ]]; then
    python3 scripts/verify-libxray-config.py --lib "${LIB}" --config "${OUT}/proxy.json"
  else
    echo "skipping libXray testXray for the desktop proxy config (needs XRAY_LOCATION_ASSET with geoip.dat)" >&2
  fi
else
  echo "libXray.so not found; skipping core construct check (set VPN_LIBXRAY_SO)" >&2
fi
if [[ -n "${XRAY1824}" ]]; then
  # Desktop proxy JSON must still load on the pinned desktop core.
  (cd "$(dirname "${XRAY1824}")" && "${XRAY1824}" run -test -c "${OUT}/proxy.json")
  echo "xray 1.8.24 accepted the desktop-parity proxy config"
else
  echo "xray 1.8.24 not found; skipping desktop binary check (set XRAY_1824_BIN)" >&2
fi

echo "verify.sh finished. This did not compile, sign, or run the iOS app."
