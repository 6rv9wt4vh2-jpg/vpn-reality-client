"""JSON profile persistence."""

from __future__ import annotations

import json
from pathlib import Path

from vpn_client.models import ProfilesStore, VlessProfile
from vpn_client.paths import PROFILES_PATH, ensure_dirs


def load_store(path: Path | None = None) -> ProfilesStore:
    ensure_dirs()
    p = path or PROFILES_PATH
    if not p.exists():
        return ProfilesStore()
    data = json.loads(p.read_text(encoding="utf-8"))
    return ProfilesStore.model_validate(data)


def save_store(store: ProfilesStore, path: Path | None = None) -> None:
    ensure_dirs()
    p = path or PROFILES_PATH
    p.write_text(
        store.model_dump_json(indent=2),
        encoding="utf-8",
    )


def get_profile(store: ProfilesStore, profile_id: str) -> VlessProfile | None:
    for p in store.profiles:
        if p.id == profile_id or p.name == profile_id:
            return p
    return None


def upsert_profile(store: ProfilesStore, profile: VlessProfile) -> ProfilesStore:
    for i, existing in enumerate(store.profiles):
        if existing.id == profile.id:
            store.profiles[i] = profile
            return store
    store.profiles.append(profile)
    return store


def delete_profile(store: ProfilesStore, profile_id: str) -> bool:
    before = len(store.profiles)
    store.profiles = [p for p in store.profiles if p.id != profile_id and p.name != profile_id]
    if store.active_id and not get_profile(store, store.active_id):
        store.active_id = None
    return len(store.profiles) < before
