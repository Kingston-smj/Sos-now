from urllib.parse import urlparse

import pytest
from fastapi.testclient import TestClient

JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 20 + b"\xff\xd9"


def _register(client: TestClient, phone: str, name: str, password: str = "secret12") -> str:
    response = client.post(
        "/auth/register",
        json={"name": name, "phone": phone, "password": password},
    )
    assert response.status_code == 201, response.text
    return response.json()["access_token"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _report(client: TestClient, token: str, **overrides) -> dict:
    fields = {
        "category": "Accident",
        "description": "Two cars collided and the road is blocked both ways.",
        "latitude": "6.5244",
        "longitude": "3.3792",
        "place_name": "Ikeja Along, Lagos",
    }
    fields.update(overrides)
    response = client.post(
        "/incidents",
        data=fields,
        files={"photo": ("scene.jpg", JPEG, "image/jpeg")},
        headers=_auth(token),
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_register_normalizes_nigerian_numbers_and_rejects_duplicates(client: TestClient):
    token = _register(client, "0803 123 4567", "Ada Obi")
    me = client.get("/auth/me", headers=_auth(token))
    assert me.status_code == 200
    assert me.json()["phone"] == "+2348031234567"
    again = client.post(
        "/auth/register",
        json={"name": "Ada Obi", "phone": "+2348031234567", "password": "secret12"},
    )
    assert again.status_code == 409


def test_login_accepts_local_and_international_formats(client: TestClient):
    _register(client, "08160001111", "Bola Ade")
    logged = client.post("/auth/login", json={"phone": "+2348160001111", "password": "secret12"})
    assert logged.status_code == 200
    bad = client.post("/auth/login", json={"phone": "08160001111", "password": "nope-nope"})
    assert bad.status_code == 401


def test_incident_is_visible_to_other_users_immediately(client: TestClient):
    ada = _register(client, "08031110001", "Ada Obi")
    bola = _register(client, "08032220002", "Bola Ade")
    created = _report(client, ada, category="Fighting", place_name="Surulere, Lagos")

    feed = client.get("/incidents", headers=_auth(bola))
    assert feed.status_code == 200
    assert len(feed.json()) == 1
    item = feed.json()[0]
    assert item["id"] == created["id"]
    assert item["category"] == "Fighting"
    assert item["place_name"] == "Surulere, Lagos"
    assert item["latitude"] == pytest.approx(6.5244)
    assert item["longitude"] == pytest.approx(3.3792)
    assert item["reporter_name"] == "Ada Obi"
    assert item["mine"] is False
    assert "phone" not in item

    photo = client.get(urlparse(item["photo_url"]).path)
    assert photo.status_code == 200
    assert photo.content == JPEG
    assert photo.headers["content-type"].startswith("image/jpeg")


def test_category_and_mine_filters(client: TestClient):
    ada = _register(client, "07031110003", "Ada Obi")
    bola = _register(client, "07032220004", "Bola Ade")
    _report(client, ada, category="Accident", place_name="Abuja-Keffi Road")
    _report(client, bola, category="Rioting", place_name="Ring Road, Benin")

    accidents = client.get("/incidents", params={"category": "Accident"}, headers=_auth(ada))
    assert [row["category"] for row in accidents.json()] == ["Accident"]

    mine = client.get("/incidents", params={"mine": "true"}, headers=_auth(ada))
    assert len(mine.json()) == 1
    assert mine.json()[0]["mine"] is True
    assert mine.json()[0]["category"] == "Accident"

    unknown = client.get("/incidents", params={"category": "Parade"}, headers=_auth(ada))
    assert unknown.status_code == 422


def test_new_incident_notifies_other_users_and_live_socket(client: TestClient):
    ada = _register(client, "09031110005", "Ada Obi")
    bola = _register(client, "09032220006", "Bola Ade")

    with client.websocket_connect(f"/ws?token={bola}") as socket:
        created = _report(client, ada, category="Fire", place_name="Aba Road, Port Harcourt")
        message = socket.receive_json()

    assert message["type"] == "incident.created"
    assert message["incident_id"] == created["id"]
    assert message["category"] == "Fire"
    assert "Aba Road, Port Harcourt" in message["message"]

    notes = client.get("/notifications", headers=_auth(bola)).json()
    assert len(notes) == 1
    assert notes[0]["read"] is False
    assert notes[0]["incident_id"] == created["id"]
    assert client.get("/notifications", headers=_auth(ada)).json() == []

    marked = client.post(f"/notifications/{notes[0]['id']}/read", headers=_auth(bola))
    assert marked.status_code == 200
    assert client.get("/notifications", headers=_auth(bola)).json()[0]["read"] is True


def test_report_requires_login_picture_and_a_real_place(client: TestClient):
    open_post = client.post("/incidents", data={"category": "Accident"})
    assert open_post.status_code == 401

    token = _register(client, "08039990007", "Chinedu Okeke")
    bad_photo = client.post(
        "/incidents",
        data={
            "category": "Robbery",
            "description": "Someone is breaking into a shop on the corner.",
            "latitude": "9.0765",
            "longitude": "7.3986",
            "place_name": "Wuse, Abuja",
        },
        files={"photo": ("notes.txt", b"not a picture", "text/plain")},
        headers=_auth(token),
    )
    assert bad_photo.status_code == 422

    bad_place = client.post(
        "/incidents",
        data={
            "category": "Medical",
            "description": "A rider is down and needs help.",
            "latitude": "95",
            "longitude": "7.4",
            "place_name": "Wuse, Abuja",
        },
        files={"photo": ("scene.jpg", JPEG, "image/jpeg")},
        headers=_auth(token),
    )
    assert bad_place.status_code == 422
