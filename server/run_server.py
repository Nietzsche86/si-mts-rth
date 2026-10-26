import os
import sys
import socket
import uvicorn

def get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

if __name__ == "__main__":
    local_ip = get_local_ip()
    port = 8000
    server_url = f"http://{local_ip}:{port}"

    print("=" * 68)
    print("   SERVER OPERATOR LOKAL — MTS ROUDHOTUT THOWALIB (v1.5)")
    print("=" * 68)
    print(f" * Status Server       : AKTIF (FastAPI + SQLite WAL)")
    print(f" * Akses Laptop Lokal  : http://localhost:{port}")
    print(f" * URL Pairing HP WiFi : {server_url}")
    print(f" * Dokumentasi API     : http://localhost:{port}/docs")
    print("-" * 68)
    print(" KREDENSI LOGIN DEFAULT:")
    print(" * Administrator : Username: admin  | PIN: 123456")
    print(" * Guru Utama    : Username: ahmad  | PIN: 123456")
    print(" * Wali Kelas 7B : Username: siti   | PIN: 123456")
    print("=" * 68)
    print(" Tekan CTRL+C untuk menghentikan server.\n")

    # Jalankan uvicorn 1 worker untuk WAL mode (PRD Bagian 7)
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False, workers=1)
