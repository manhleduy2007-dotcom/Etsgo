import os
from uuid import uuid4

import jwt
import pytest
from fastapi.testclient import TestClient

# Explicitly named local test database; never default to the application database.
os.environ.setdefault("DATABASE_URL", "postgresql+psycopg://etsgo@127.0.0.1:55432/etsgo_test")
os.environ["ENVIRONMENT"] = "development"
os.environ["DEV_AUTH_SECRET"] = "etsgo-tests-only-not-a-production-secret-12345"
if not os.environ["DATABASE_URL"].endswith("/etsgo_test"):
    raise RuntimeError("Tests require a dedicated etsgo_test database")

from app.main import app  # noqa: E402


@pytest.fixture
def client():
    return TestClient(app, raise_server_exceptions=True)


@pytest.fixture
def user():
    from datetime import UTC, datetime, timedelta
    identity = str(uuid4())
    token = jwt.encode({"sub": identity, "aud": "etsgo-dev", "exp": datetime.now(UTC)+timedelta(hours=1)}, os.environ["DEV_AUTH_SECRET"])
    return identity, {"Authorization": "Bearer "+token}
