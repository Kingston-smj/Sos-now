from datetime import datetime

from pydantic import BaseModel, Field


class UserOut(BaseModel):
    id: int
    phone: str
    name: str


class AuthOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class RegisterIn(BaseModel):
    name: str = Field(min_length=1, max_length=60)
    phone: str = Field(min_length=7, max_length=20)
    password: str = Field(min_length=6, max_length=72)


class LoginIn(BaseModel):
    phone: str
    password: str


class IncidentOut(BaseModel):
    id: int
    category: str
    description: str
    latitude: float
    longitude: float
    place_name: str
    photo_url: str
    created_at: datetime
    reporter_name: str
    mine: bool


class NotificationOut(BaseModel):
    id: int
    message: str
    read: bool
    created_at: datetime
    incident_id: int
    category: str
    place_name: str
