import time
import uuid
from typing import Optional
from sqlmodel import SQLModel, Field

def current_time_epoch_ms() -> int:
    return int(time.time() * 1000)

def generate_uuid() -> str:
    return str(uuid.uuid4())

class SyncBaseModel(SQLModel):
    """
    Model dasar wajib untuk semua tabel yang disinkronkan sesuai CLAUDE.md & PRD Bagian 9.1:
    - id (TEXT PRIMARY KEY — UUID v4)
    - created_at (INTEGER NOT NULL — epoch ms UTC)
    - updated_at (INTEGER NOT NULL — epoch ms UTC)
    - deleted (INTEGER NOT NULL DEFAULT 0 — soft delete 0/1)
    - device_id (TEXT NOT NULL)
    - server_seq (INTEGER — diisi monotonik oleh server, indexed)
    """
    id: str = Field(default_factory=generate_uuid, primary_key=True, index=True)
    created_at: int = Field(default_factory=current_time_epoch_ms)
    updated_at: int = Field(default_factory=current_time_epoch_ms, index=True)
    deleted: int = Field(default=0, index=True)
    device_id: str = Field(default="server")
    server_seq: Optional[int] = Field(default=None, index=True)
