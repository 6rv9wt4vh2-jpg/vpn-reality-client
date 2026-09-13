"""Typer CLI: connect / disconnect / import / list / status / ui / install-xray."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.table import Table

from vpn_client import __version__
from vpn_client.import_link import import_any
from vpn_client.models import RealitySettings, VlessProfile
from vpn_client import process as proc
from vpn_client.store import delete_profile, get_profile, load_store, save_store, upsert_profile
from vpn_client.xray_config import build_xray_config, write_xray_config
from vpn_client.paths import GENERATED_CONFIG, ensure_dirs

app = typer.Typer(
    name="vpn-reality",
    help="VLESS + Reality desktop client MVP (xray-core)",
    no_args_is_help=True,
)
console = Console()


@app.callback()
def _main() -> None:
    ensure_dirs()


@app.command("version")
def version_cmd() -> None:
    console.print(f"vpn-reality-client {__version__}")


@app.command("install-xray")
def install_xray_cmd(
    version: str = typer.Option("1.8.24", help="Xray-core release version"),
) -> None:
    """Download official Xray-core into ./bin."""
    from vpn_client.install_xray import download_xray

    path = download_xray(version=version)
    console.print(f"[green]Installed[/green] {path}")


@app.command("list")
def list_cmd() -> None:
    """List saved profiles."""
    store = load_store()
    if not store.profiles:
        console.print("No profiles. Import one: [cyan]vpn-reality import ...[/cyan]")
        return
    table = Table(title="Profiles")
    table.add_column("ID", style="dim", max_width=10)
    table.add_column("Name")
    table.add_column("Server")
    table.add_column("SNI")
    table.add_column("Active")
    for p in store.profiles:
        table.add_row(
            p.id[:8],
            p.name,
            f"{p.address}:{p.port}",
            p.primary_sni(),
            "✓" if p.id == store.active_id else "",
        )
    console.print(table)


@app.command("import")
def import_cmd(
    source: str = typer.Argument(..., help="vless:// URI, JSON string, or path to file"),
    name: Optional[str] = typer.Option(None, "--name", "-n", help="Override profile name"),
) -> None:
    """Import a VLESS Reality link or JSON profile."""
    path = Path(source)
    if path.is_file():
        text = path.read_text(encoding="utf-8")
    else:
        text = source
    profile = import_any(text)
    if name:
        profile.name = name
    store = load_store()
    upsert_profile(store, profile)
    if not store.active_id:
        store.active_id = profile.id
    save_store(store)
    console.print(f"[green]Imported[/green] {profile.name} ({profile.id[:8]}) → {profile.address}:{profile.port}")


@app.command("add")
def add_cmd(
    name: str = typer.Option(..., "--name", "-n"),
    address: str = typer.Option(..., "--address", "-a"),
    port: int = typer.Option(443, "--port", "-p"),
    uuid: str = typer.Option(..., "--uuid", "-u"),
    public_key: str = typer.Option(..., "--pbk", help="Reality public key"),
    short_id: str = typer.Option("", "--sid", help="Reality shortId"),
    sni: str = typer.Option("www.cloudflare.com", "--sni"),
    fingerprint: str = typer.Option("chrome", "--fp"),
    flow: str = typer.Option("xtls-rprx-vision", "--flow"),
    spider_x: str = typer.Option("/", "--spx"),
    socks_port: int = typer.Option(10808, "--socks"),
    http_port: Optional[int] = typer.Option(10809, "--http"),
) -> None:
    """Add a profile from flags (placeholders OK for testing)."""
    profile = VlessProfile(
        name=name,
        address=address,
        port=port,
        uuid=uuid,
        flow=flow,
        socks_port=socks_port,
        http_port=http_port,
        reality=RealitySettings(
            public_key=public_key,
            short_id=short_id,
            server_names=[s.strip() for s in sni.split(",") if s.strip()],
            fingerprint=fingerprint,
            spider_x=spider_x,
        ),
    )
    store = load_store()
    upsert_profile(store, profile)
    save_store(store)
    console.print(f"[green]Added[/green] {profile.name} ({profile.id})")


@app.command("remove")
def remove_cmd(profile_id: str = typer.Argument(..., help="Profile id or name")) -> None:
    store = load_store()
    if delete_profile(store, profile_id):
        save_store(store)
        console.print("[green]Removed[/green]")
    else:
        console.print("[red]Not found[/red]")
        raise typer.Exit(1)


@app.command("show-config")
def show_config_cmd(
    profile_id: Optional[str] = typer.Argument(None, help="Profile id/name (default: active)"),
    write: bool = typer.Option(False, "--write", help=f"Write to {GENERATED_CONFIG}"),
) -> None:
    """Print generated xray JSON for a profile."""
    store = load_store()
    pid = profile_id or store.active_id
    if not pid:
        console.print("[red]No active profile[/red]")
        raise typer.Exit(1)
    profile = get_profile(store, pid)
    if not profile:
        console.print("[red]Profile not found[/red]")
        raise typer.Exit(1)
    if write:
        cfg = write_xray_config(profile, GENERATED_CONFIG)
        console.print(f"Wrote {GENERATED_CONFIG}")
    else:
        cfg = build_xray_config(profile)
    console.print_json(json.dumps(cfg))


@app.command("connect")
def connect_cmd(
    profile_id: Optional[str] = typer.Argument(None, help="Profile id/name (default: active)"),
) -> None:
    """Generate config and start xray."""
    store = load_store()
    pid = profile_id or store.active_id
    if not pid:
        console.print("[red]No profile. Import or add one first.[/red]")
        raise typer.Exit(1)
    profile = get_profile(store, pid)
    if not profile:
        console.print("[red]Profile not found[/red]")
        raise typer.Exit(1)
    store.active_id = profile.id
    save_store(store)
    st = proc.start(profile)
    style = "green" if st.running else "red"
    console.print(st.message, style=style)
    if not st.running:
        raise typer.Exit(1)


@app.command("disconnect")
def disconnect_cmd() -> None:
    """Stop xray."""
    st = proc.stop()
    console.print(st.message, markup=False)


@app.command("status")
def status_cmd() -> None:
    st = proc.status()
    console.print(st.message, markup=False)
    if st.binary:
        console.print(f"binary: {st.binary}", markup=False)
    if st.config_path:
        console.print(f"config: {st.config_path}", markup=False)


@app.command("ui")
def ui_cmd(
    host: str = typer.Option("127.0.0.1", "--host"),
    port: int = typer.Option(8787, "--port"),
) -> None:
    """Start local web dashboard (FastAPI)."""
    import uvicorn

    console.print(f"Dashboard → http://{host}:{port}")
    uvicorn.run("vpn_client.webapp:app", host=host, port=port, log_level="info")


if __name__ == "__main__":
    app()
