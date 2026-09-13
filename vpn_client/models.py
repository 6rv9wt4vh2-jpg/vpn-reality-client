"""Profile and Reality config models."""

from __future__ import annotations

from typing import Literal
from uuid import uuid4

from pydantic import BaseModel, Field, field_validator


class RealitySettings(BaseModel):
    """XTLS Reality client settings (first-class fields)."""

    public_key: str = Field(..., description="Server Reality public key (pbk)")
    short_id: str = Field(default="", description="Reality shortId (sid), hex")
    server_names: list[str] = Field(
        default_factory=lambda: ["www.cloudflare.com"],
        description="SNI / serverNames list",
    )
    fingerprint: str = Field(default="chrome", description="uTLS fingerprint")
    spider_x: str = Field(default="/", description="spiderX path")
    # dest is typically server-side; kept for documentation / import parity
    dest: str | None = Field(
        default=None,
        description="Server dest (usually only on server inbound; optional here)",
    )

    @field_validator("server_names", mode="before")
    @classmethod
    def _coerce_server_names(cls, v):  # noqa: ANN001
        if isinstance(v, str):
            return [s.strip() for s in v.split(",") if s.strip()]
        return v


class VlessProfile(BaseModel):
    """Stored client profile: VLESS + Reality outbound."""

    id: str = Field(default_factory=lambda: str(uuid4()))
    name: str = Field(..., min_length=1)
    address: str = Field(..., description="Server host or IP")
    port: int = Field(..., ge=1, le=65535)
    uuid: str = Field(..., description="VLESS user UUID")
    flow: str = Field(default="xtls-rprx-vision", description="VLESS flow")
    encryption: Literal["none"] = "none"
    network: Literal["tcp"] = "tcp"
    security: Literal["reality"] = "reality"
    reality: RealitySettings
    socks_port: int = Field(default=10808, ge=1, le=65535)
    http_port: int | None = Field(default=10809, description="Optional HTTP inbound")
    notes: str = ""

    def primary_sni(self) -> str:
        return self.reality.server_names[0] if self.reality.server_names else "www.example.com"


class ProfilesStore(BaseModel):
    profiles: list[VlessProfile] = Field(default_factory=list)
    active_id: str | None = None
