import hashlib
import hmac
from datetime import timedelta
from uuid import NAMESPACE_URL, UUID, uuid5

import jwt
import openai
from fastapi import Header

from .config import settings
from .db import Entity, Session, now, save
from .sync import Problem


def session_secret():
    cfg = settings()
    secret = cfg.app_session_secret or (cfg.dev_auth_secret if cfg.environment == "development" else "")
    if len(secret) < 32:
        raise Problem(503, "session_secret_not_configured")
    return secret


def issue_session(owner):
    secret = session_secret()
    def token(use, lifetime):
        return jwt.encode({"sub": owner, "aud": "etsgo", "iss": "etsgo-api-key",
                           "iat": now(), "exp": now()+lifetime, "token_use": use}, secret, algorithm="HS256")
    return {"access_token": token("access", timedelta(hours=1)),
            "refresh_token": token("refresh", timedelta(days=7)), "user": {"id": owner}}


def decode_session(token, use):
    try:
        claims = jwt.decode(token, session_secret(), algorithms=["HS256"], audience="etsgo", issuer="etsgo-api-key",
                            options={"require": ["exp", "iat", "sub", "token_use"]})
        owner = str(UUID(claims["sub"]))
        if claims["token_use"] != use:
            raise ValueError("wrong token use")
    except (jwt.PyJWTError, KeyError, ValueError):
        raise Problem(401, "invalid_token") from None
    with Session() as db:
        row = db.get(Entity, (owner, "credential", "openai"))
        if not row or row.deleted:
            raise Problem(401, "session_revoked")
    return owner


def login_api_key(api_key):
    from .calendar import cipher
    cfg = settings()
    session_secret()
    encryption = cipher()
    if not cfg.ai_model:
        raise Problem(503, "ai_model_not_configured")
    try:
        with openai.OpenAI(api_key=api_key, max_retries=0, timeout=20) as client:
            client.models.retrieve(cfg.ai_model)
    except openai.AuthenticationError:
        raise Problem(401, "invalid_openai_key") from None
    except (openai.PermissionDeniedError, openai.NotFoundError):
        raise Problem(403, "openai_model_unavailable") from None
    except openai.RateLimitError:
        raise Problem(429, "openai_rate_limited") from None
    except openai.APIError:
        raise Problem(503, "openai_unavailable") from None
    # Key-derived demo identity: same key on this server maps to the same data.
    fingerprint = hmac.new(cfg.encryption_key.encode(), api_key.encode(), hashlib.sha256).hexdigest()
    owner = str(uuid5(NAMESPACE_URL, "etsgo:key:"+fingerprint))
    with Session.begin() as db:
        save(db, owner, "credential", "openai", {"encrypted_key": encryption.encrypt(api_key.encode()).decode()})
    return issue_session(owner)


def authenticate(authorization: str = Header(default="")):
    cfg = settings()
    if not authorization.startswith("Bearer "):
        raise Problem(401, "authentication_required")
    token = authorization[7:]
    try:
        if cfg.environment == "development" and len(cfg.dev_auth_secret) >= 32:
            try:
                claims = jwt.decode(token, cfg.dev_auth_secret, algorithms=["HS256"], audience="etsgo-dev")
                return str(UUID(claims["sub"]))
            except jwt.PyJWTError:
                pass
        return decode_session(token, "access")
    except (jwt.PyJWTError, KeyError, ValueError):
        raise Problem(401, "invalid_token") from None
