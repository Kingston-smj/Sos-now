import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db import init_db, make_engine, session_factory
from app.hub import Hub
from app.routes import register_routes

BACKEND_ROOT = Path(__file__).resolve().parent.parent


def resolve_settings() -> tuple[str, Path, str]:
    database_url = os.environ.get("SOS_DATABASE")
    if not database_url:
        data_dir = BACKEND_ROOT / "data"
        data_dir.mkdir(parents=True, exist_ok=True)
        database_url = f"sqlite:///{data_dir / 'sos.db'}"
    upload_dir = Path(os.environ.get("SOS_UPLOAD_DIR", BACKEND_ROOT / "uploads"))
    upload_dir.mkdir(parents=True, exist_ok=True)
    secret = os.environ.get("SOS_SECRET", "dev-only-change-me-before-you-share-this")
    return database_url, upload_dir, secret


def create_app() -> FastAPI:
    database_url, upload_dir, secret = resolve_settings()
    engine = make_engine(database_url)
    init_db(engine)
    app = FastAPI(title="SOS Now", version="1.0.0")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.state.engine = engine
    app.state.SessionLocal = session_factory(engine)
    app.state.upload_dir = upload_dir
    app.state.secret = secret
    app.state.hub = Hub()
    register_routes(app)
    return app


app = create_app()
