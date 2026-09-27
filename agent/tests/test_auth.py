import pytest
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient
from firebase_admin import auth as firebase_auth

from outing_agent.api import auth as auth_module

APP_SENTINEL = object()


@pytest.fixture
def verify(monkeypatch):
    class Stub:
        result = {"uid": "user-123"}
        error = None
        calls = []

    def fake_verify(token, app=None, check_revoked=False, clock_skew_seconds=0):
        Stub.calls.append({"token": token, "app": app, "check_revoked": check_revoked})
        if Stub.error is not None:
            raise Stub.error
        return Stub.result

    Stub.calls = []
    monkeypatch.setattr(auth_module, "get_firebase_app", lambda: APP_SENTINEL)
    monkeypatch.setattr(firebase_auth, "verify_id_token", fake_verify)
    return Stub


@pytest.fixture
def client():
    app = FastAPI()

    @app.get("/whoami")
    def whoami(uid: str = Depends(auth_module.get_verified_uid)):
        return {"uid": uid}

    return TestClient(app)


def _assert_bare_401(response):
    assert response.status_code == 401
    assert response.json() == {"detail": "Unauthorized"}
    assert response.headers.get("www-authenticate") == "Bearer"


def test_valid_token_returns_uid(client, verify):
    response = client.get("/whoami", headers={"Authorization": "Bearer good-token"})

    assert response.status_code == 200
    assert response.json() == {"uid": "user-123"}
    assert verify.calls[0]["token"] == "good-token"
    assert verify.calls[0]["app"] is APP_SENTINEL


def test_missing_header_is_401(client, verify):
    _assert_bare_401(client.get("/whoami"))
    assert verify.calls == []


@pytest.mark.parametrize(
    "header",
    ["Token good-token", "Bearer", "Bearer ", "good-token", "Basic dXNlcjpwYXNz"],
)
def test_malformed_header_is_401(client, verify, header):
    _assert_bare_401(client.get("/whoami", headers={"Authorization": header}))
    assert verify.calls == []


@pytest.mark.parametrize(
    "error",
    [
        firebase_auth.InvalidIdTokenError("secret reason: bad signature"),
        firebase_auth.ExpiredIdTokenError("secret reason: expired", cause=None),
        firebase_auth.RevokedIdTokenError("secret reason: revoked"),
        firebase_auth.UserDisabledError("secret reason: disabled"),
        ValueError("secret reason: empty token"),
    ],
)
def test_token_that_fails_verification_is_401_without_detail(client, verify, error):
    verify.error = error

    response = client.get("/whoami", headers={"Authorization": "Bearer bad-token"})

    _assert_bare_401(response)
    assert "secret reason" not in response.text


def test_decoded_token_without_uid_is_401(client, verify):
    verify.result = {}

    _assert_bare_401(client.get("/whoami", headers={"Authorization": "Bearer odd-token"}))


def test_certificate_fetch_failure_is_503_not_401(client, verify):
    verify.error = firebase_auth.CertificateFetchError("secret reason: network", cause=None)

    response = client.get("/whoami", headers={"Authorization": "Bearer good-token"})

    assert response.status_code == 503
    assert "secret reason" not in response.text


@pytest.mark.parametrize("setting", [False, True])
def test_check_revoked_follows_config(client, verify, monkeypatch, setting):
    monkeypatch.setattr(auth_module, "CHECK_REVOKED", setting)

    client.get("/whoami", headers={"Authorization": "Bearer good-token"})

    assert verify.calls[0]["check_revoked"] is setting