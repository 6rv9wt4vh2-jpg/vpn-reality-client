"""Minimal FastAPI + HTML dashboard."""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from vpn_client import __version__, process as proc
from vpn_client.import_link import import_any
from vpn_client.paths import WEB_STATIC, ensure_dirs
from vpn_client.store import delete_profile, get_profile, load_store, save_store, upsert_profile

ensure_dirs()
app = FastAPI(title="VPN Reality Client", version=__version__)

if WEB_STATIC.is_dir():
    app.mount("/static", StaticFiles(directory=str(WEB_STATIC)), name="static")


class ImportBody(BaseModel):
    text: str
    name: str | None = None


@app.get("/", response_class=HTMLResponse)
def index() -> HTMLResponse:
    index_path = WEB_STATIC / "index.html"
    if index_path.exists():
        return HTMLResponse(index_path.read_text(encoding="utf-8"))
    return HTMLResponse("<h1>vpn-reality-client</h1><p>static UI missing</p>")


@app.get("/api/status")
def api_status():
    st = proc.status()
    store = load_store()
    return {
        "running": st.running,
        "pid": st.pid,
        "message": st.message,
        "binary": st.binary,
        "config_path": st.config_path,
        "active_id": store.active_id,
        "version": __version__,
    }


@app.get("/api/profiles")
def api_profiles():
    store = load_store()
    return {
        "active_id": store.active_id,
        "profiles": [p.model_dump() for p in store.profiles],
    }


@app.post("/api/import")
def api_import(body: ImportBody):
    try:
        profile = import_any(body.text)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(400, str(e)) from e
    if body.name:
        profile.name = body.name
    store = load_store()
    upsert_profile(store, profile)
    if not store.active_id:
        store.active_id = profile.id
    save_store(store)
    return profile.model_dump()


@app.delete("/api/profiles/{profile_id}")
def api_delete(profile_id: str):
    store = load_store()
    if not delete_profile(store, profile_id):
        raise HTTPException(404, "not found")
    save_store(store)
    return {"ok": True}


@app.post("/api/connect/{profile_id}")
def api_connect(profile_id: str):
    store = load_store()
    profile = get_profile(store, profile_id)
    if not profile:
        raise HTTPException(404, "profile not found")
    store.active_id = profile.id
    save_store(store)
    st = proc.start(profile)
    if not st.running:
        raise HTTPException(500, st.message)
    return {"ok": True, "message": st.message, "pid": st.pid}


@app.post("/api/disconnect")
def api_disconnect():
    st = proc.stop()
    return {"ok": True, "message": st.message}


@app.get("/favicon.ico")
def favicon():
    return FileResponse(WEB_STATIC / "index.html") if False else HTMLResponse("", status_code=204)
