import re
import uuid
from pathlib import Path

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.categories import CATEGORIES
from app.deps import get_current_user, get_db
from app.models import Incident, Notification, User
from app.phones import normalize_phone
from app.schemas import (
    AuthOut,
    IncidentOut,
    LoginIn,
    NotificationOut,
    RegisterIn,
    UserOut,
)
from app.security import create_token, hash_password, user_from_token, verify_password

MAX_PHOTO_BYTES = 5 * 1024 * 1024
_PHOTO_NAME = re.compile(r"[a-f0-9]{32}\.(jpg|png|webp)")
router = APIRouter()


def _clean_name(raw: str) -> str:
    name = " ".join(raw.split())
    if not 2 <= len(name) <= 60:
        raise HTTPException(status_code=422, detail="Enter your name")
    return name


def _clean_password(raw: str) -> str:
    if not 6 <= len(raw) <= 72:
        raise HTTPException(status_code=422, detail="Password must be at least 6 characters")
    return raw


def _auth_response(user: User, secret: str) -> AuthOut:
    return AuthOut(
        access_token=create_token(user.id, secret),
        user=UserOut(id=user.id, phone=user.phone, name=user.name),
    )


def _photo_url(request: Request, photo_name: str) -> str:
    base = str(request.base_url).rstrip("/")
    return f"{base}/uploads/{photo_name}"


def _incident_out(request: Request, incident: Incident, viewer: User) -> IncidentOut:
    return IncidentOut(
        id=incident.id,
        category=incident.category,
        description=incident.description,
        latitude=incident.latitude,
        longitude=incident.longitude,
        place_name=incident.place_name,
        photo_url=_photo_url(request, incident.photo_name),
        created_at=incident.created_at,
        reporter_name=incident.reporter.name,
        mine=incident.user_id == viewer.id,
    )


def _sniff_image(data: bytes) -> str | None:
    if data.startswith(b"\xff\xd8\xff"):
        return "jpg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if len(data) >= 12 and data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "webp"
    return None


@router.get("/health")
def health():
    return {"ok": True, "service": "SOS Now"}


@router.get("/categories")
def categories():
    return {"categories": list(CATEGORIES)}


@router.post("/auth/register", response_model=AuthOut, status_code=201)
def register(body: RegisterIn, request: Request, db: Session = Depends(get_db)):
    try:
        phone = normalize_phone(body.phone)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    name = _clean_name(body.name)
    password = _clean_password(body.password)
    existing = db.scalar(select(User).where(User.phone == phone))
    if existing is not None:
        raise HTTPException(status_code=409, detail="An account with this phone number already exists")
    user = User(phone=phone, name=name, password_hash=hash_password(password))
    db.add(user)
    db.commit()
    db.refresh(user)
    return _auth_response(user, request.app.state.secret)


@router.post("/auth/login", response_model=AuthOut)
def login(body: LoginIn, request: Request, db: Session = Depends(get_db)):
    try:
        phone = normalize_phone(body.phone)
    except ValueError:
        raise HTTPException(status_code=401, detail="Phone number or password is incorrect")
    user = db.scalar(select(User).where(User.phone == phone))
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Phone number or password is incorrect")
    return _auth_response(user, request.app.state.secret)


@router.get("/auth/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return UserOut(id=user.id, phone=user.phone, name=user.name)


@router.get("/incidents", response_model=list[IncidentOut])
def list_incidents(
    request: Request,
    category: str | None = None,
    mine: bool = False,
    limit: int = Query(100, ge=1, le=200),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if category is not None and category not in CATEGORIES:
        raise HTTPException(status_code=422, detail="Unknown category")
    stmt = select(Incident).options(joinedload(Incident.reporter)).order_by(Incident.created_at.desc())
    if category is not None:
        stmt = stmt.where(Incident.category == category)
    if mine:
        stmt = stmt.where(Incident.user_id == user.id)
    rows = db.scalars(stmt.limit(limit)).unique().all()
    return [_incident_out(request, row, user) for row in rows]


@router.get("/incidents/{incident_id}", response_model=IncidentOut)
def get_incident(
    incident_id: int,
    request: Request,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    incident = db.scalar(
        select(Incident).options(joinedload(Incident.reporter)).where(Incident.id == incident_id)
    )
    if incident is None:
        raise HTTPException(status_code=404, detail="Incident not found")
    return _incident_out(request, incident, user)


@router.post("/incidents", response_model=IncidentOut, status_code=201)
async def create_incident(
    request: Request,
    category: str = Form(),
    description: str = Form(),
    latitude: float = Form(),
    longitude: float = Form(),
    place_name: str = Form(),
    photo: UploadFile = File(),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if category not in CATEGORIES:
        raise HTTPException(status_code=422, detail="Choose a category")
    description = " ".join(description.split())
    if not 10 <= len(description) <= 2000:
        raise HTTPException(status_code=422, detail="Describe the incident in at least 10 characters")
    place = " ".join(place_name.split())
    if not 2 <= len(place) <= 120:
        raise HTTPException(status_code=422, detail="Enter the place, such as a street and city")
    if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
        raise HTTPException(status_code=422, detail="Latitude or longitude is out of range")

    blob = await photo.read(MAX_PHOTO_BYTES + 1)
    if len(blob) > MAX_PHOTO_BYTES:
        raise HTTPException(status_code=422, detail="Picture must be 5 MB or smaller")
    ext = _sniff_image(blob)
    if ext is None:
        raise HTTPException(status_code=422, detail="Picture must be a JPEG, PNG, or WebP")

    photo_name = f"{uuid.uuid4().hex}.{ext}"
    path: Path = request.app.state.upload_dir / photo_name
    path.write_bytes(blob)

    incident = Incident(
        user_id=user.id,
        category=category,
        description=description,
        latitude=latitude,
        longitude=longitude,
        place_name=place,
        photo_name=photo_name,
    )
    try:
        db.add(incident)
        db.flush()
        message = f"New {category} reported at {place}"
        others = db.scalars(select(User.id).where(User.id != user.id)).all()
        db.add_all(
            Notification(user_id=other_id, incident_id=incident.id, message=message)
            for other_id in others
        )
        db.commit()
    except Exception:
        db.rollback()
        path.unlink(missing_ok=True)
        raise
    db.refresh(incident)
    incident.reporter = user

    await request.app.state.hub.broadcast(
        {
            "type": "incident.created",
            "incident_id": incident.id,
            "category": incident.category,
            "place_name": incident.place_name,
            "message": f"New {incident.category} reported at {incident.place_name}",
        },
        exclude_user_id=user.id,
    )
    return _incident_out(request, incident, user)


@router.get("/notifications", response_model=list[NotificationOut])
def list_notifications(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = db.execute(
        select(Notification, Incident)
        .join(Incident, Notification.incident_id == Incident.id)
        .where(Notification.user_id == user.id)
        .order_by(Notification.created_at.desc())
        .limit(100)
    ).all()
    return [
        NotificationOut(
            id=note.id,
            message=note.message,
            read=note.read,
            created_at=note.created_at,
            incident_id=incident.id,
            category=incident.category,
            place_name=incident.place_name,
        )
        for note, incident in rows
    ]


@router.post("/notifications/read-all")
def read_all(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    notes = db.scalars(select(Notification).where(Notification.user_id == user.id, Notification.read.is_(False))).all()
    for note in notes:
        note.read = True
    db.commit()
    return {"ok": True}


@router.post("/notifications/{notification_id}/read")
def read_one(
    notification_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    note = db.get(Notification, notification_id)
    if note is None or note.user_id != user.id:
        raise HTTPException(status_code=404, detail="Alert not found")
    note.read = True
    db.commit()
    return {"ok": True}


def register_routes(app) -> None:
    app.include_router(router)

    @app.get("/uploads/{filename}")
    def download_photo(filename: str):
        if _PHOTO_NAME.fullmatch(filename) is None:
            raise HTTPException(status_code=404, detail="Picture not found")
        ext = filename.rsplit(".", 1)[-1]
        media = {"jpg": "image/jpeg", "png": "image/png", "webp": "image/webp"}.get(ext)
        path = app.state.upload_dir / filename
        if media is None or not path.is_file():
            raise HTTPException(status_code=404, detail="Picture not found")
        return FileResponse(path, media_type=media)

    @app.websocket("/ws")
    async def live(websocket: WebSocket):
        token = websocket.query_params.get("token", "")
        db = websocket.app.state.SessionLocal()
        try:
            user = user_from_token(db, token, websocket.app.state.secret)
        finally:
            db.close()
        if user is None:
            await websocket.accept()
            await websocket.close(code=4401)
            return
        await websocket.app.state.hub.connect(user.id, websocket)
        try:
            while True:
                await websocket.receive_text()
        except WebSocketDisconnect:
            pass
        finally:
            websocket.app.state.hub.disconnect(user.id, websocket)

