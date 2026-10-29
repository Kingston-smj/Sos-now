from pathlib import Path

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import sessionmaker

from app.models import Base


def sqlite_file(url: str) -> Path | None:
    prefix = "sqlite:///"
    if not url.startswith(prefix):
        return None
    raw = url[len(prefix) :]
    if raw in ("", ":memory:"):
        return None
    return Path(raw)


def make_engine(url: str) -> Engine:
    path = sqlite_file(url)
    if path is not None:
        path.parent.mkdir(parents=True, exist_ok=True)
    kwargs = {}
    if url.startswith("sqlite"):
        kwargs["connect_args"] = {"check_same_thread": False}
    engine = create_engine(url, **kwargs)
    if url.startswith("sqlite"):

        @event.listens_for(engine, "connect")
        def _enable_foreign_keys(conn, _record):
            cursor = conn.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

    return engine


def init_db(engine: Engine) -> None:
    Base.metadata.create_all(engine)


def session_factory(engine: Engine):
    return sessionmaker(bind=engine, expire_on_commit=False, autoflush=False)
