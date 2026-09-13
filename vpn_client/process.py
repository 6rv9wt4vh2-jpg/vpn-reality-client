"""Start / stop / status for xray-core subprocess."""

from __future__ import annotations

import os
import signal
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path

from vpn_client.models import VlessProfile
from vpn_client.paths import GENERATED_CONFIG, PID_FILE, RUNTIME_DIR, ensure_dirs, find_xray_binary
from vpn_client.xray_config import write_xray_config


@dataclass
class ProcessStatus:
    running: bool
    pid: int | None
    config_path: str | None
    binary: str | None
    message: str


def _read_pid() -> int | None:
    if not PID_FILE.exists():
        return None
    try:
        return int(PID_FILE.read_text(encoding="utf-8").strip())
    except ValueError:
        return None


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def status() -> ProcessStatus:
    ensure_dirs()
    binary = find_xray_binary()
    pid = _read_pid()
    if pid and _pid_alive(pid):
        return ProcessStatus(
            running=True,
            pid=pid,
            config_path=str(GENERATED_CONFIG) if GENERATED_CONFIG.exists() else None,
            binary=str(binary) if binary else None,
            message=f"xray running (pid {pid})",
        )
    if pid and not _pid_alive(pid):
        PID_FILE.unlink(missing_ok=True)
    return ProcessStatus(
        running=False,
        pid=None,
        config_path=str(GENERATED_CONFIG) if GENERATED_CONFIG.exists() else None,
        binary=str(binary) if binary else None,
        message="xray not running",
    )


def start(profile: VlessProfile, binary: Path | None = None) -> ProcessStatus:
    ensure_dirs()
    st = status()
    if st.running:
        return ProcessStatus(
            running=True,
            pid=st.pid,
            config_path=st.config_path,
            binary=st.binary,
            message=f"already running (pid {st.pid}); disconnect first",
        )

    xray = binary or find_xray_binary()
    if not xray:
        return ProcessStatus(
            running=False,
            pid=None,
            config_path=None,
            binary=None,
            message="xray binary not found. Install with: python -m vpn_client.install_xray",
        )

    write_xray_config(profile, GENERATED_CONFIG)
    log_path = RUNTIME_DIR / "xray.log"
    log_f = open(log_path, "ab", buffering=0)  # noqa: SIM115
    try:
        proc = subprocess.Popen(
            [str(xray), "run", "-c", str(GENERATED_CONFIG)],
            stdout=log_f,
            stderr=subprocess.STDOUT,
            cwd=str(xray.parent),  # geoip.dat / geosite.dat live next to binary
            start_new_session=True,
        )
    except OSError as e:
        log_f.close()
        return ProcessStatus(
            running=False,
            pid=None,
            config_path=str(GENERATED_CONFIG),
            binary=str(xray),
            message=f"failed to start xray: {e}",
        )

    # Brief settle — if process dies immediately, surface error
    time.sleep(0.4)
    if proc.poll() is not None:
        log_f.close()
        tail = ""
        if log_path.exists():
            tail = log_path.read_text(encoding="utf-8", errors="replace")[-800:]
        return ProcessStatus(
            running=False,
            pid=None,
            config_path=str(GENERATED_CONFIG),
            binary=str(xray),
            message=f"xray exited immediately (code {proc.returncode}). Log:\n{tail}",
        )

    PID_FILE.write_text(str(proc.pid), encoding="utf-8")
    return ProcessStatus(
        running=True,
        pid=proc.pid,
        config_path=str(GENERATED_CONFIG),
        binary=str(xray),
        message=(
            f"started pid={proc.pid}; SOCKS5 127.0.0.1:{profile.socks_port}"
            + (f"; HTTP 127.0.0.1:{profile.http_port}" if profile.http_port else "")
        ),
    )


def stop() -> ProcessStatus:
    ensure_dirs()
    pid = _read_pid()
    if not pid:
        return ProcessStatus(
            running=False,
            pid=None,
            config_path=None,
            binary=str(find_xray_binary()) if find_xray_binary() else None,
            message="not running",
        )
    if not _pid_alive(pid):
        PID_FILE.unlink(missing_ok=True)
        return ProcessStatus(
            running=False,
            pid=None,
            config_path=None,
            binary=str(find_xray_binary()) if find_xray_binary() else None,
            message="stale pid cleared",
        )
    try:
        os.kill(pid, signal.SIGTERM)
    except OSError as e:
        return ProcessStatus(
            running=_pid_alive(pid),
            pid=pid,
            config_path=str(GENERATED_CONFIG) if GENERATED_CONFIG.exists() else None,
            binary=str(find_xray_binary()) if find_xray_binary() else None,
            message=f"kill failed: {e}",
        )
    for _ in range(20):
        if not _pid_alive(pid):
            break
        time.sleep(0.1)
    if _pid_alive(pid):
        try:
            os.kill(pid, signal.SIGKILL)
        except OSError:
            pass
    PID_FILE.unlink(missing_ok=True)
    return ProcessStatus(
        running=False,
        pid=None,
        config_path=str(GENERATED_CONFIG) if GENERATED_CONFIG.exists() else None,
        binary=str(find_xray_binary()) if find_xray_binary() else None,
        message=f"stopped (was pid {pid})",
    )
