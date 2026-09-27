from pathlib import Path

import firebase_admin
import pytest

from outing_agent import firebase_app

ENV_VARS = (
    "FIREBASE_SERVICE_ACCOUNT_JSON",
    "FIREBASE_SERVICE_ACCOUNT_PATH",
    "GOOGLE_CLOUD_PROJECT",
)


class FakeCertificate:
    def __init__(self, cert):
        self.cert = cert


class FakeApplicationDefault:
    pass


@pytest.fixture(autouse=True)
def fake_firebase(monkeypatch):
    for name in ENV_VARS:
        monkeypatch.delenv(name, raising=False)

    calls = []

    def no_app(*args, **kwargs):
        raise ValueError("no app")

    def record_init(credential=None, options=None, name="[DEFAULT]"):
        calls.append({"credential": credential, "options": options})
        return "app"

    monkeypatch.setattr(firebase_admin, "get_app", no_app)
    monkeypatch.setattr(firebase_admin, "initialize_app", record_init)
    monkeypatch.setattr(firebase_app.credentials, "Certificate", FakeCertificate)
    monkeypatch.setattr(firebase_app.credentials, "ApplicationDefault", FakeApplicationDefault)
    return calls


def test_agent_dir_is_agent_folder():
    assert firebase_app.AGENT_DIR == Path(__file__).resolve().parents[1]


def test_empty_json_falls_through_to_path(monkeypatch, tmp_path, fake_firebase):
    key = tmp_path / "key.json"
    key.write_text("{}")
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_JSON", "   ")
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_PATH", str(key))

    firebase_app.get_firebase_app()

    assert fake_firebase[0]["credential"].cert == str(key)


def test_missing_key_path_raises(monkeypatch, tmp_path, fake_firebase):
    missing = tmp_path / "nope.json"
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_PATH", str(missing))

    with pytest.raises(FileNotFoundError, match="nope.json"):
        firebase_app.get_firebase_app()
    assert fake_firebase == []


def test_relative_path_resolves_against_agent_dir(monkeypatch, tmp_path, fake_firebase):
    (tmp_path / "key.json").write_text("{}")
    monkeypatch.setattr(firebase_app, "AGENT_DIR", tmp_path)
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_PATH", "./key.json")
    monkeypatch.chdir(tmp_path.parent)

    firebase_app.get_firebase_app()

    assert Path(fake_firebase[0]["credential"].cert) == tmp_path / "key.json"


def test_adc_with_project_id(monkeypatch, fake_firebase):
    monkeypatch.setenv("GOOGLE_CLOUD_PROJECT", "demo-project")

    firebase_app.get_firebase_app()

    assert isinstance(fake_firebase[0]["credential"], FakeApplicationDefault)
    assert fake_firebase[0]["options"] == {"projectId": "demo-project"}


def test_adc_without_project_id_passes_no_options(fake_firebase):
    firebase_app.get_firebase_app()

    assert isinstance(fake_firebase[0]["credential"], FakeApplicationDefault)
    assert fake_firebase[0]["options"] is None


def test_invalid_json_error_hides_contents(monkeypatch, fake_firebase):
    secret = '{"private_key": "SECRET_MARKER"'
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_JSON", secret)

    with pytest.raises(ValueError) as excinfo:
        firebase_app.get_firebase_app()

    exc = excinfo.value
    assert "FIREBASE_SERVICE_ACCOUNT_JSON" in str(exc)
    assert "SECRET_MARKER" not in str(exc)
    assert "SECRET_MARKER" not in str(exc.__cause__)
    assert exc.__cause__ is None
    assert exc.__suppress_context__ is True
    assert fake_firebase == []
