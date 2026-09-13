"""Download official Xray-core release into ./bin (Linux amd64/arm64)."""

from __future__ import annotations

import io
import platform
import shutil
import sys
import zipfile
from pathlib import Path
from urllib.request import Request, urlopen

from vpn_client.paths import BIN_DIR, ensure_dirs

# Pin a known-good release; bump as needed.
XRAY_VERSION = "1.8.24"
GITHUB_RELEASE = (
    f"https://github.com/XTLS/Xray-core/releases/download/"
    f"v{XRAY_VERSION}/Xray-linux-{{arch}}.zip"
)


def _arch() -> str:
    m = platform.machine().lower()
    if m in ("x86_64", "amd64"):
        return "64"
    if m in ("aarch64", "arm64"):
        return "arm64-v8a"
    raise RuntimeError(f"unsupported architecture: {m}")


def download_xray(dest_dir: Path | None = None, version: str = XRAY_VERSION) -> Path:
    ensure_dirs()
    out_dir = dest_dir or BIN_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    arch = _arch()
    url = (
        f"https://github.com/XTLS/Xray-core/releases/download/"
        f"v{version}/Xray-linux-{arch}.zip"
    )
    print(f"Downloading {url} ...")
    req = Request(url, headers={"User-Agent": "vpn-reality-client/0.1"})
    with urlopen(req, timeout=120) as resp:  # noqa: S310 — official GitHub release
        data = resp.read()
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        members = zf.namelist()
        # extract xray binary and optional geo assets
        for name in members:
            base = Path(name).name
            if base in ("xray", "geoip.dat", "geosite.dat"):
                target = out_dir / base
                with zf.open(name) as src, open(target, "wb") as dst:
                    shutil.copyfileobj(src, dst)
                if base == "xray":
                    target.chmod(0o755)
    binary = out_dir / "xray"
    if not binary.is_file():
        raise RuntimeError("xray binary missing after extract")
    print(f"Installed: {binary}")
    return binary


def main() -> None:
    try:
        path = download_xray()
        print(f"OK: {path}")
    except Exception as e:  # noqa: BLE001
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
