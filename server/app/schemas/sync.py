from typing import List, Optional, Dict, Any
from pydantic import BaseModel

class SyncChangeItem(BaseModel):
    local_seq: Optional[int] = None
    table: str
    operation: str  # 'UPSERT' | 'DELETE'
    row: Dict[str, Any]

class SyncPushRequest(BaseModel):
    device_id: str
    last_pulled_seq: Optional[int] = 0
    changes: List[SyncChangeItem]

class SyncPushResultItem(BaseModel):
    local_seq: Optional[int] = None
    status: str  # 'APPLIED' | 'MERGED_BY_BUSINESS_KEY' | 'REJECTED'
    canonical_id: Optional[str] = None
    server_seq: Optional[int] = None
    message: Optional[str] = None

class SyncPushResponse(BaseModel):
    results: List[SyncPushResultItem]

class ActiveScope(BaseModel):
    semester_aktif_id: Optional[str] = None
    wali_rombel_ids: List[str] = []
    pengampu_ids: List[str] = []
    allowed_keanggotaan_ids: List[str] = []

class SyncPullChangeItem(BaseModel):
    table: str
    server_seq: int
    row: Dict[str, Any]

class SyncPullResponse(BaseModel):
    from_seq: int
    to_seq: int
    has_more: bool
    recalculate_scope: bool
    active_scope: ActiveScope
    changes: List[SyncPullChangeItem]
