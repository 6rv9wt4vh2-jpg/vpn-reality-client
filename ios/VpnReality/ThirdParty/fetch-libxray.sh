#!/usr/bin/env bash
# Helper for Mac developers — does not embed proprietary/stolen binaries.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "== VpnReality ThirdParty helper =="
echo "Target dir: $ROOT"
echo

if [[ "$(uname -s)" != "Darwin" ]]; then
  cat <<'MSG'
This script must run on macOS with Xcode + Go (for building LibXray).

Linux/CI cannot produce a usable iOS xcframework here.

Recommended:
  1) Open ios/VpnReality/VpnReality.xcodeproj on a Mac
  2) Add SPM: https://github.com/dima-u/SwiftyXrayKit
     OR build LibXray.xcframework via https://github.com/XTLS/libXray
  3) Link into VpnRealityTunnel target
  4) Uncomment the canImport(SwiftyXrayKit)/LibXray path in PacketTunnelProvider.swift

Placeholder layout after you add the framework:
  ThirdParty/LibXray.xcframework/
  ThirdParty/.gitkeep stays so the folder exists in git
MSG
  exit 2
fi

echo "macOS detected."
echo "Clone/build options (pick one):"
echo
echo "  # A) SPM in Xcode (easiest)"
echo "  # File → Add Package Dependencies → https://github.com/dima-u/SwiftyXrayKit"
echo
echo "  # B) Build LibXray with gomobile (see XTLS/libXray README)"
echo "  # go install golang.org/x/mobile/cmd/gomobile@latest"
echo "  # gomobile init"
echo "  # Follow libXray 'iOS && macOS' → produce LibXray.xcframework"
echo "  # cp -R LibXray.xcframework \"$ROOT/\""
echo
if [[ -d "$ROOT/LibXray.xcframework" ]]; then
  echo "Found LibXray.xcframework — ready to link in Xcode."
else
  echo "LibXray.xcframework not present yet."
  exit 3
fi
