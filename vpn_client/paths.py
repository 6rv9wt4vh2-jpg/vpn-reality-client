"""Project paths and defaults."""

from __future__ import annotations

from pathlib import Path

# Repo root: .../vpn-reality-client
ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
PROFILES_PATH = DATA_DIR / "profiles.json"
RUNTIME_DIR = DATA_DIR / "runtime"
GENERATED_CONFIG = RUNTIME_DIR / "xray-config.json"
PID_FILE = RUNTIME_DIR / "xray.pid"
BIN_DIR = ROOT / "bin"
WEB_STATIC = ROOT / "web" / "static"

DEFAULT_SOCKS_PORT = 10808
DEFAULT_HTTP_PORT = 10809
DEFAULT_XRAY_API_PORT = 10085


def ensure_dirs() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    BIN_DIR.mkdir(parents=True, exist_ok=True)


def find_xray_binary() -> Path | None:
    """Locate xray binary: PATH, then ./bin/xray."""
    import shutil

    which = shutil.which("xray")
    if which:
        return Path(which)
    local = BIN_DIR / "xray"
    if local.is_file() and local.stat().st_mode & 0o111:
        return local
    return None
