import os
import tempfile
from pathlib import Path

# Settings are read when the app module loads, so point tests at a throwaway
# database before that import.
_root = Path(tempfile.mkdtemp(prefix="sos-now-tests-"))
os.environ["SOS_DATABASE"] = f"sqlite:///{_root / 'test.db'}"
os.environ["SOS_UPLOAD_DIR"] = str(_root / "uploads")
os.environ["SOS_SECRET"] = "test-secret-at-least-32-bytes-long"

import pytest
from fastapi.testclient import TestClient

from app.hub import Hub
from app.main import app
from app.models import Incident, Notification, User


@pytest.fixture()
def client():
    db = app.state.SessionLocal()
    db.query(Notification).delete()
    db.query(Incident).delete()
    db.query(User).delete()
    db.commit()
    db.close()
    app.state.hub = Hub()
    upload = Path(app.state.upload_dir)
    upload.mkdir(parents=True, exist_ok=True)
    for path in upload.iterdir():
        if path.is_file():
            path.unlink()
    with TestClient(app) as test_client:
        yield test_client
