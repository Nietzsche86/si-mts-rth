from fastapi.testclient import TestClient
from sqlmodel import Session

def test_full_auth_and_sync_flow(client: TestClient, session: Session):
    # 1. Setup Admin awal
    setup_resp = client.post("/api/v1/auth/setup-admin", json={
        "username": "admin_mts",
        "pin": "123456",
        "nama_madrasah": "MTS ROUDHOTUT THOWALIB"
    })
    assert setup_resp.status_code == 200
    
    # 2. Login
    login_resp = client.post("/api/v1/auth/login", json={
        "username": "admin_mts",
        "pin": "123456",
        "device_id": "laptop-operator-01",
        "nama_perangkat": "Laptop Operator Lenovo"
    })
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # 3. Push Master Data (Tahun Ajaran & Mapel)
    push_data = {
        "device_id": "laptop-operator-01",
        "last_pulled_seq": 0,
        "changes": [
            {
                "local_seq": 1,
                "table": "tahun_ajaran",
                "operation": "UPSERT",
                "row": {
                    "id": "ta-2026-2027",
                    "nama": "2026/2027",
                    "tanggal_mulai": "2026-07-15",
                    "tanggal_selesai": "2027-06-25",
                    "aktif": 1,
                    "created_at": 1761440000000,
                    "updated_at": 1761440000000,
                    "deleted": 0,
                    "device_id": "laptop-operator-01"
                }
            },
            {
                "local_seq": 2,
                "table": "mapel",
                "operation": "UPSERT",
                "row": {
                    "id": "mapel-qurdis",
                    "kode": "QURDIS",
                    "nama": "Al-Qur'an Hadis",
                    "kelompok": "PAI",
                    "urutan": 1,
                    "aktif": 1,
                    "created_at": 1761440000000,
                    "updated_at": 1761440000000,
                    "deleted": 0,
                    "device_id": "laptop-operator-01"
                }
            }
        ]
    }
    push_resp = client.post("/api/v1/sync/push", json=push_data, headers=headers)
    assert push_resp.status_code == 200
    push_res = push_resp.json()
    assert len(push_res["results"]) == 2
    assert push_res["results"][0]["status"] == "APPLIED"
    assert push_res["results"][1]["status"] == "APPLIED"
    
    # 4. Pull
    pull_resp = client.get("/api/v1/sync/pull?since_seq=0", headers=headers)
    assert pull_resp.status_code == 200
    pull_res = pull_resp.json()
    assert len(pull_res["changes"]) >= 2
    
    # 5. Lock sync (Admin mutasi massal)
    lock_resp = client.post("/api/v1/sync/lock", headers=headers)
    assert lock_resp.status_code == 200
    
    # Push saat sync terkunci -> Wajib ditolak HTTP 503
    push_locked_resp = client.post("/api/v1/sync/push", json=push_data, headers=headers)
    assert push_locked_resp.status_code == 503
    
    # 6. Unlock sync
    unlock_resp = client.post("/api/v1/sync/unlock", headers=headers)
    assert unlock_resp.status_code == 200
    
    # Push kembali diterima
    push_unlocked_resp = client.post("/api/v1/sync/push", json=push_data, headers=headers)
    assert push_unlocked_resp.status_code == 200
