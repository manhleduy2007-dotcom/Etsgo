import hashlib
import secrets
from datetime import timedelta
from urllib.parse import urlencode

import httpx
from cryptography.fernet import Fernet

from .config import settings
from .db import Entity, Session, now, save
from .sync import Problem, entities

GOOGLE = "https://www.googleapis.com/calendar/v3"


def cipher():
    if not settings().encryption_key:
        raise Problem(503, "encryption_not_configured")
    return Fernet(settings().encryption_key.encode())


def google_start(db, owner):
    cfg = settings()
    if not cfg.google_client_id:
        raise Problem(503, "google_not_configured")
    cipher()
    state = secrets.token_urlsafe(32)
    save(db, owner, "oauth", hashlib.sha256(state.encode()).hexdigest(),
         {"expires": (now()+timedelta(minutes=10)).isoformat()})
    query = {"client_id": cfg.google_client_id, "redirect_uri": cfg.public_url+"/v1/calendar/google/callback",
             "response_type": "code", "access_type": "offline", "prompt": "consent", "state": owner+":"+state,
             "scope": "https://www.googleapis.com/auth/calendar.calendarlist.readonly "
                      "https://www.googleapis.com/auth/calendar.events.freebusy "
                      "https://www.googleapis.com/auth/calendar.app.created"}
    return "https://accounts.google.com/o/oauth2/v2/auth?"+urlencode(query)


def google_finish(state, code):
    from .scheduler import parse
    from .db import lock_account
    try:
        owner, token = state.split(":", 1)
        from uuid import UUID
        owner = str(UUID(owner))
    except ValueError:
        raise Problem(400, "invalid_oauth_state") from None
    with Session.begin() as db:
        lock_account(db, owner)
        item = db.get(Entity, (owner, "oauth", hashlib.sha256(token.encode()).hexdigest()))
        if not item or item.deleted or parse(item.data["expires"]) < now():
            raise Problem(400, "invalid_oauth_state")
        item.deleted = True
        old = db.get(Entity, (owner, "connection", "google"))
        app_calendar = old.data.get("app_calendar") if old else None
    cfg = settings()
    response = httpx.post("https://oauth2.googleapis.com/token", data={"code": code,
                          "client_id": cfg.google_client_id, "client_secret": cfg.google_client_secret,
                          "redirect_uri": cfg.public_url+"/v1/calendar/google/callback",
                          "grant_type": "authorization_code"}, timeout=20)
    if response.is_error or not response.json().get("refresh_token"):
        raise Problem(400, "google_authorization_failed")
    token_data = response.json()
    if not app_calendar:
        created = httpx.post(GOOGLE+"/calendars", headers={"Authorization": "Bearer "+token_data["access_token"]},
                             json={"summary": "Etsgo"}, timeout=20)
        created.raise_for_status()
        app_calendar = created.json()["id"]
    with Session.begin() as db:
        save(db, owner, "connection", "google", {"refresh": cipher().encrypt(token_data["refresh_token"].encode()).decode(),
             "app_calendar": app_calendar, "read_calendars": ["primary"]})
    return owner


def google_token(connection):
    cfg = settings()
    response = httpx.post("https://oauth2.googleapis.com/token", data={
        "client_id": cfg.google_client_id, "client_secret": cfg.google_client_secret,
        "refresh_token": cipher().decrypt(connection.data["refresh"].encode()).decode(),
        "grant_type": "refresh_token"}, timeout=20)
    if response.status_code in {400, 401, 403}:
        raise Problem(409, "google_reconnect_required")
    response.raise_for_status()
    return response.json()["access_token"]


def google_busy(owner, start, end):
    from types import SimpleNamespace
    with Session() as db:
        row = db.get(Entity, (owner, "connection", "google"))
        if not row or row.deleted:
            return
        connection = SimpleNamespace(data=dict(row.data))
    token = google_token(connection)
    calendars = [c for c in connection.data["read_calendars"] if c != connection.data["app_calendar"]]
    response = httpx.post(GOOGLE+"/freeBusy", headers={"Authorization": "Bearer "+token},
                          json={"timeMin": start.isoformat(), "timeMax": end.isoformat(),
                                "items": [{"id": c} for c in calendars]}, timeout=20)
    response.raise_for_status()
    intervals = []
    for data in response.json()["calendars"].values():
        if data.get("errors"):
            raise Problem(503, "calendar_read_failed")
        intervals.extend(data.get("busy", []))
    with Session.begin() as db:
        save(db, owner, "busy", "google", {"intervals": intervals, "fetched_at": now().isoformat(),
             "range_start": start.isoformat(), "range_end": end.isoformat(), "source": "google"})


def busy_data(db, owner):
    from .scheduler import parse
    result, stale = [], []
    for row in entities(db, owner, "busy"):
        if row.data.get("disabled"):
            continue
        if now()-parse(row.data["fetched_at"]) > timedelta(seconds=settings().busy_max_age_seconds):
            stale.append(row.id)
        result.extend(row.data["intervals"])
    return result, stale


def export_google(connection, action):
    """Deterministic Google event ID makes uncertain create retries safe."""
    token = google_token(connection)
    headers = {"Authorization": "Bearer "+token}
    calendar_id = connection.data["app_calendar"]
    from urllib.parse import quote
    base = GOOGLE+"/calendars/"+quote(calendar_id, safe="")+"/events"
    event_id = hashlib.sha256(action["planned_id"].encode()).hexdigest()
    body = {"summary": action["title"], "start": {"dateTime": action["start"]},
            "end": {"dateTime": action["end"]},
            "extendedProperties": {"private": {"etsgo_id": action["planned_id"], "revision": str(action["revision"])}}}
    with httpx.Client(timeout=20, headers=headers) as client:
        existing = client.get(base+"/"+event_id)
        if action.get("action") == "delete":
            if existing.status_code == 404 or existing.status_code == 410:
                return {"external_id": event_id, "calendar_id": calendar_id, "removed": True}
            existing.raise_for_status()
            old = existing.json()
            if old.get("extendedProperties", {}).get("private", {}).get("etsgo_id") != action["planned_id"]:
                raise Problem(409, "calendar_reconcile_required")
            if action.get("previous_etag") and old["etag"] != action["previous_etag"]:
                raise Problem(409, "calendar_reconcile_required")
            response = client.delete(base+"/"+event_id, headers={"If-Match": old["etag"]})
            response.raise_for_status()
            return {"external_id": event_id, "calendar_id": calendar_id, "removed": True}
        if existing.status_code == 404:
            response = client.post(base, json={"id": event_id, **body})
            if response.status_code == 409:
                response = client.get(base+"/"+event_id)
        else:
            existing.raise_for_status()
            old = existing.json()
            props = old.get("extendedProperties", {}).get("private", {})
            if props.get("etsgo_id") != action["planned_id"]:
                raise Problem(409, "calendar_reconcile_required")
            from .scheduler import parse
            same = (parse(old["start"]["dateTime"]) == parse(action["start"]) and
                    parse(old["end"]["dateTime"]) == parse(action["end"]) and old["summary"] == action["title"])
            if same and props.get("revision") == str(action["revision"]):
                return {"external_id": event_id, "calendar_id": calendar_id, "etag": old["etag"]}
            if action.get("previous_etag") and old["etag"] != action["previous_etag"]:
                raise Problem(409, "calendar_reconcile_required")
            response = client.patch(base+"/"+event_id, json=body, headers={"If-Match": old["etag"]})
        response.raise_for_status()
        return {"external_id": event_id, "calendar_id": calendar_id, "etag": response.json().get("etag")}
