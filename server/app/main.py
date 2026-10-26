from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db.engine import init_db
from app.api.auth import router as auth_router
from app.api.sync import router as sync_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Inisialisasi Database SQLite WAL dan 5 Partial Unique Index wajib
    init_db()
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    lifespan=lifespan
)

# CORS Middleware (mengizinkan koneksi WiFi klien lokal)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Registrasi Router
app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(sync_router, prefix=settings.API_V1_STR)

@app.get("/health")
def healthcheck():
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION
    }

if __name__ == "__main__":
    import uvicorn
    # Menjalankan 1 worker sesuai PRD Bagian 7 untuk SQLite WAL
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True, workers=1)
