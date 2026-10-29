# SOS Now

Citizens incident reporting for Nigeria. A person submits an accident, fight, riot, or other incident. It is stored immediately, other signed-in people can browse it, and they get an alert.

The phone app is Flutter. The server is a Python API. Each incident is one record: category, description, place, latitude, longitude, and a picture. Login is a Nigerian phone number and a password, and Mine shows only that person's reports.

## Run the server

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Open http://127.0.0.1:8000/docs to try the API. Set `SOS_SECRET` to a long random string before sharing the server with anyone else. The database file is `backend/data/sos.db`. Pictures are stored in `backend/uploads/`.

## Run the app

Flutter is already unpacked in `.tools/flutter` in this repo. From the repo folder:

```bash
export PATH="$PWD/.tools/flutter/bin:$PATH"
cd app
flutter pub get
flutter run
```

On an Android emulator, set the server address on the login screen to `http://10.0.2.2:8000`. On a phone, use this computer's Wi-Fi address, for example `http://192.168.1.20:8000`. The phone and the computer have to be on the same network.

Android is allowed to call that local address over plain HTTP so a class demo does not need a certificate. Use HTTPS when this is hosted for real.

## Alerts

While the app is open it listens for new incidents and shows a banner, and the Alerts tab keeps them. It also checks the server every 20 seconds, so a dropped connection still catches up. Phone alerts when the app has been swiped away need Firebase Cloud Messaging and a project file that is not included here.

## Tests

```bash
cd backend
.venv/bin/pytest
```

```bash
cd app
flutter test
```
