from typing import Annotated

from fastapi import Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session

from app.models import User
from app.security import user_from_token


def get_db(request: Request):
    db: Session = request.app.state.SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(
    request: Request,
    authorization: Annotated[str | None, Header()] = None,
    db: Session = Depends(get_db),
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Login required")
    token = authorization.split(" ", 1)[1].strip()
    user = user_from_token(db, token, request.app.state.secret)
    if user is None:
        raise HTTPException(status_code=401, detail="Login required")
    return user
