from functools import lru_cache
from uuid import UUID

import httpx
import jwt
from fastapi import Header

from .config import settings
from .sync import Problem


@lru_cache
def jwks():
    return jwt.PyJWKClient(settings().supabase_url + "/auth/v1/.well-known/jwks.json", cache_jwk_set=True)


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
        if not cfg.supabase_url:
            raise Problem(401, "invalid_token")
        claims = jwt.decode(token, jwks().get_signing_key_from_jwt(token).key,
                            algorithms=["ES256", "RS256"], audience="authenticated",
                            issuer=cfg.supabase_url + "/auth/v1",
                            options={"require": ["exp", "sub", "iat"]})
        return str(UUID(claims["sub"]))
    except (jwt.PyJWTError, KeyError, ValueError):
        raise Problem(401, "invalid_token") from None


def supabase(path, payload):
    cfg = settings()
    if not cfg.supabase_url or not cfg.supabase_anon_key:
        raise Problem(503, "auth_not_configured")
    response = httpx.post(cfg.supabase_url + "/auth/v1/" + path, json=payload,
                          headers={"apikey": cfg.supabase_anon_key}, timeout=20)
    if response.is_error:
        raise Problem(429 if response.status_code == 429 else 401, "authentication_failed")
    return response.json()
