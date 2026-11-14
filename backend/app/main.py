import json
from datetime import timedelta
from typing import Annotated

from fastapi import Depends, FastAPI, Header, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, Field, ValidationError
from sqlalchemy import select, text

from . import calendar
from .ai import prompt_context
from .auth import authenticate, supabase
from .config import settings
from .db import Change, Entity, Job, Session, lock_account, now, save, uid
from .schemas import MessageInput, PlanTurn, Push
from .scheduler import parse, schedule, validate_sessions
from .sync import Problem, apply, digest, entities, planning_signature, remember, replay, singleton

app = FastAPI(title="Etsgo", version="1.0.0")
User = Annotated[str, Depends(authenticate)]
Key = Annotated[str, Header(alias="Idempotency-Key", min_length=1, max_length=100)]


@app.middleware("http")
async def request_id(request: Request, call_next):
    request.state.request_id = uid()
    response = await call_next(request)
    response.headers["X-Request-ID"] = request.state.request_id
    return response


@app.exception_handler(Problem)
async def problem(request, exc):
    return JSONResponse(status_code=exc.status, content={"error": {"code": exc.code,
        "message": exc.code.replace("_", " "), "details": exc.details}, "request_id": request.state.request_id})


@app.exception_handler(RequestValidationError)
async def bad_input(request, exc):
    return await problem(request, Problem(422, "invalid_request"))


@app.exception_handler(ValidationError)
async def bad_data(request, exc):
    return await problem(request, Problem(422, "invalid_payload"))


@app.exception_handler(Exception)
async def internal_error(request, exc):
    import httpx
    if isinstance(exc, httpx.HTTPError):
        return await problem(request, Problem(503, "upstream_unavailable"))
    return await problem(request, Problem(500, "internal_error"))


@app.get("/health")
def health():
    with Session() as db:
        db.execute(text("SELECT 1"))
    return {"status": "ok"}


class AuthInput(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    code: str = Field(default="", max_length=10)


@app.post("/v1/auth/development")
def development_login(request: Request):
    cfg = settings()
    if cfg.environment != "development" or len(cfg.dev_auth_secret) < 32 or request.client.host not in {"127.0.0.1", "::1", "testclient"}:
        raise Problem(404, "not_found")
    import jwt
    from uuid import NAMESPACE_URL, uuid5
    owner = str(uuid5(NAMESPACE_URL, "etsgo:local-developer"))
    token = jwt.encode({"sub": owner, "aud": "etsgo-dev", "exp": now()+timedelta(days=1)}, cfg.dev_auth_secret)
    return {"access_token": token, "refresh_token": "", "user": {"id": owner}}


@app.post("/v1/auth/otp")
def otp(body: AuthInput):
    supabase("otp", {"email": body.email, "create_user": True})
    return {"sent": True}


@app.post("/v1/auth/verify")
def verify(body: AuthInput):
    return supabase("verify", {"email": body.email, "token": body.code, "type": "email"})


@app.post("/v1/auth/refresh")
def refresh(body: dict):
    return supabase("token?grant_type=refresh_token", {"refresh_token": body.get("refresh_token", "")})


@app.get("/v1/me")
def me(user: User):
    with Session.begin() as db:
        account = lock_account(db, user)
        return {"id": user, "revision": account.revision,
                "profile": singleton(db, user, "profile", {"language": "vi", "timezone": "Asia/Bangkok"})}


@app.post("/v1/sync/push")
def push(body: Push, user: User):
    results = []
    for operation in body.operations:
        try:
            with Session.begin() as db:
                results.append(apply(db, user, operation))
        except (Problem, ValidationError) as exc:
            results.append({"operation_id": str(operation.operation_id), "status": "error",
                            "code": exc.code if isinstance(exc, Problem) else "invalid_payload"})
            break  # Preserve dependency order after a failed parent.
        if results[-1]["status"] == "conflict":
            break
    return {"results": results}


@app.get("/v1/sync/pull")
def pull(user: User, cursor: int = 0, limit: int = 200, until: int | None = None):
    if cursor < 0 or not 1 <= limit <= 500:
        raise Problem(422, "invalid_cursor")
    with Session.begin() as db:
        account = lock_account(db, user)
        boundary = account.revision if until is None else until
        if not cursor <= boundary <= account.revision:
            raise Problem(409, "bootstrap_required")
        rows = list(db.scalars(select(Change).where(Change.owner == user, Change.seq > cursor,
                             Change.seq <= boundary).order_by(Change.seq).limit(limit)))
        next_cursor = rows[-1].seq if rows else boundary
        return {"changes": [r.body for r in rows], "cursor": next_cursor,
                "until": boundary, "has_more": next_cursor < boundary}


def new_job(db, user, kind, payload, key, quota=True):
    lock_account(db, user)
    request_payload = {k: v for k, v in payload.items() if k not in {"context", "now"}}
    previous = replay(db, user, key, request_payload)
    if previous:
        return previous
    day = str(now().date())
    if quota:
        row = db.get(Entity, (user, "quota", day))
        used = row.data["used"] if row else 0
        if used >= settings().daily_ai_limit:
            raise Problem(429, "quota_exceeded")
        save(db, user, "quota", day, {"used": used+1})
    job = Job(id=uid(), owner=user, kind=kind, payload=payload, quota_day=day if quota else None)
    db.add(job)
    return remember(db, user, key, request_payload, {"job_id": job.id})


@app.get("/v1/usage")
def usage(user: User):
    with Session() as db:
        row = db.get(Entity, (user, "quota", str(now().date())))
        used = row.data["used"] if row else 0
        return {"used": used, "limit": settings().daily_ai_limit, "period": str(now().date())}


@app.get("/v1/jobs/{identity}")
def job(identity: str, user: User):
    with Session() as db:
        row = db.get(Job, identity)
        if not row or row.owner != user:
            raise Problem(404, "not_found")
        return {"id": row.id, "status": row.status, "result": row.result, "error": row.error}


@app.post("/v1/imports/local")
def import_local(body: Push, user: User, key: Key):
    with Session.begin() as db:
        lock_account(db, user)
        payload = body.model_dump(mode="json")
        previous = replay(db, user, "import:"+key, payload)
        if previous:
            return previous
        results = [apply(db, user, op) for op in body.operations]
        return remember(db, user, "import:"+key, payload, {"results": results})


@app.post("/v1/conversations")
def create_conversation(user: User, key: Key):
    with Session.begin() as db:
        lock_account(db, user)
        previous = replay(db, user, "conversation:"+key, {})
        if previous:
            return previous
        row = save(db, user, "conversation", uid(), {"messages": []})
        return remember(db, user, "conversation:"+key, {}, {"id": row.id})


@app.get("/v1/conversations/{identity}")
def get_conversation(identity: str, user: User):
    with Session() as db:
        row = db.get(Entity, (user, "conversation", identity))
        if not row:
            raise Problem(404, "not_found")
        return {"id": identity, **row.data}


@app.post("/v1/conversations/{identity}/messages", status_code=202)
def message(identity: str, body: MessageInput, user: User, key: Key):
    with Session.begin() as db:
        lock_account(db, user)
        row = db.get(Entity, (user, "conversation", identity))
        if not row:
            raise Problem(404, "not_found")
        previous = replay(db, user, "message:"+key, body.model_dump(mode="json"))
        if previous:
            return previous
        if any(j.payload.get("conversation_id") == identity for j in db.scalars(select(Job).where(
                Job.owner == user, Job.kind == "plan", Job.status.in_(["queued", "running"])) )):
            raise Problem(409, "conversation_busy")
        messages = row.data["messages"] + [{"role": "user", "content": body.text or "Just propose first"}]
        payload = {"conversation_id": identity, "messages": messages[-30:],
                   "context": prompt_context(db, user), "draft": body.draft, "force_proposal": body.force_proposal,
                   "input_signature": planning_signature(db, user)}
        output = new_job(db, user, "plan", payload, "plan:"+key)
        save(db, user, "conversation", identity, {"messages": messages, "job_id": output["job_id"]})
        return remember(db, user, "message:"+key, body.model_dump(mode="json"), output)


@app.post("/v1/context/imports", status_code=202)
def handoff(body: MessageInput, user: User, key: Key):
    with Session.begin() as db:
        return new_job(db, user, "handoff", {"text": body.text, "context": prompt_context(db, user)}, "handoff:"+key)


@app.post("/v1/ai/{action}", status_code=202)
def ai_action(action: str, body: dict, user: User, key: Key):
    if action not in {"parse", "breakdown", "prioritize"}:
        raise Problem(404, "not_found")
    if len(json.dumps(body)) > 60000:
        raise Problem(422, "input_too_large")
    with Session.begin() as db:
        return new_job(db, user, action, {"input": body, "context": prompt_context(db, user), "now": now().isoformat()}, action+":"+key)


@app.post("/v1/tasks/{identity}/{action}", status_code=202)
def task_ai(identity: str, action: str, body: dict, user: User, key: Key):
    if action not in {"guidance", "unblock"}:
        raise Problem(404, "not_found")
    with Session.begin() as db:
        task = db.get(Entity, (user, "task", identity))
        if not task or task.deleted:
            raise Problem(404, "not_found")
        return new_job(db, user, action, {"task": task.data, "request": body,
                       "context": prompt_context(db, user, identity)}, action+":"+key)


def schedule_inputs(db, user):
    tasks = [{**r.data, "id": r.id, "version": r.version} for r in entities(db, user, "task")]
    default_week = {"days": [{"windows": [{"start": 1140, "end": 1320}], "commitment": 60} for _ in range(7)]}
    week = singleton(db, user, "week", default_week)["days"]
    commitments = {r.data["day"]: r.data["minutes"] for r in entities(db, user, "commitment")}
    profile = singleton(db, user, "profile", {"timezone": "Asia/Bangkok", "language": "vi"})
    busy, stale = calendar.busy_data(db, user)
    versions = [(r.kind, r.id, r.version) for kind in ("task", "week", "commitment", "profile", "busy") for r in entities(db, user, kind)]
    return tasks, week, commitments, profile["timezone"], busy, stale, digest(sorted(versions))


@app.post("/v1/schedule/proposals")
def schedule_proposal(user: User, key: Key):
    calendar.google_busy(user, now(), now()+timedelta(days=15))
    with Session.begin() as db:
        lock_account(db, user)
        previous = replay(db, user, "schedule:"+key, {})
        if previous:
            return previous
        tasks, week, commitments, zone, busy, stale, revision = schedule_inputs(db, user)
        result = schedule(tasks, week, commitments, busy, zone, now())
        row = save(db, user, "proposal", uid(), {"type": "schedule", "status": "draft", "input_revision": revision,
                   **result, "task_versions": {t["id"]: t["version"] for t in tasks},
                   "warnings": ["calendar_stale:"+s for s in stale] + ([] if entities(db, user, "busy") else ["calendar_not_connected"])})
        return remember(db, user, "schedule:"+key, {}, {"id": row.id, "version": row.version, **row.data})


class ProposalEdit(BaseModel):
    expected_version: int
    turn: PlanTurn | None = None
    sessions: list[dict] | None = Field(default=None, max_length=1000)


@app.get("/v1/proposals/{identity}")
def get_proposal(identity: str, user: User):
    with Session() as db:
        row = db.get(Entity, (user, "proposal", identity))
        if not row:
            raise Problem(404, "not_found")
        return {"id": row.id, "version": row.version, **row.data}


@app.patch("/v1/proposals/{identity}")
def edit_proposal(identity: str, body: ProposalEdit, user: User):
    with Session.begin() as db:
        lock_account(db, user)
        row = db.get(Entity, (user, "proposal", identity))
        if not row or row.data["status"] != "draft" or row.version != body.expected_version:
            raise Problem(409, "proposal_stale")
        data = dict(row.data)
        if body.turn and data["type"] == "plan":
            data["turn"] = body.turn.model_dump(mode="json")
        elif body.sessions is not None and data["type"] == "schedule":
            # Only removal is permitted by this minimal editing contract.
            originals = {s["id"]: s for s in data["sessions"]}
            if any(s != originals.get(s.get("id")) for s in body.sessions):
                raise Problem(422, "invalid_session_edit")
            data["sessions"] = body.sessions
        else:
            raise Problem(422, "invalid_proposal_edit")
        row = save(db, user, "proposal", identity, data)
        return {"id": identity, "version": row.version, **row.data}


@app.post("/v1/proposals/{identity}/{decision}")
def decide(identity: str, decision: str, body: dict, user: User, key: Key):
    if decision not in {"accept", "reject"}:
        raise Problem(404, "not_found")
    if decision == "accept":
        with Session() as read_db:
            candidate = read_db.get(Entity, (user, "proposal", identity))
            refresh_calendar = candidate and candidate.data["type"] == "schedule" and candidate.data["status"] == "draft"
        if refresh_calendar:
            calendar.google_busy(user, now(), now()+timedelta(days=15))
    with Session.begin() as db:
        lock_account(db, user)
        payload = {"id": identity, "decision": decision, **body}
        previous = replay(db, user, "decision:"+key, payload)
        if previous:
            return previous
        row = db.get(Entity, (user, "proposal", identity))
        if not row or row.data["status"] != "draft" or row.version != body.get("expected_version"):
            raise Problem(409, "proposal_stale")
        data = dict(row.data)
        if decision == "accept":
            if data["type"] == "plan":
                if data.get("input_signature") != planning_signature(db, user):
                    raise Problem(409, "proposal_stale")
                from .schemas import TaskData
                goal = save(db, user, "task", uid(), TaskData(title=data["turn"]["title"] or "Study plan").model_dump(mode="json"))
                for order, step in enumerate(data["turn"]["steps"]):
                    task = TaskData(**step, parent_id=goal.id, order=order)
                    save(db, user, "task", uid(), task.model_dump(mode="json"))
            else:
                # Refresh Google before final validation; the proposal is not blindly trusted.
                tasks, week, commitments, zone, busy, stale, revision = schedule_inputs(db, user)
                if stale:
                    raise Problem(409, "calendar_stale", stale)
                # Busy refresh may change version without changing content. Task/context
                # changes are validated against captured task versions below.
                captured = data.get("task_versions", {})
                if captured != {t["id"]: t["version"] for t in tasks}:
                    raise Problem(409, "proposal_stale")
                try:
                    validate_sessions(data["sessions"], tasks, week, commitments, busy, zone, now())
                except (ValueError, KeyError) as exc:
                    raise Problem(409, "schedule_invalid", str(exc)) from None
                for planned in entities(db, user, "planned"):
                    if parse(planned.data["end"]) > now():
                        save(db, user, "planned", planned.id, planned.data, True)
                for entry in data["sessions"]:
                    save(db, user, "planned", entry["id"], {**entry, "proposal_id": identity})
        data["status"] = "accepted" if decision == "accept" else "rejected"
        save(db, user, "proposal", identity, data)
        return remember(db, user, "decision:"+key, payload, {"status": data["status"]})


@app.post("/v1/calendar/eventkit/snapshots")
def eventkit_snapshot(body: dict, user: User):
    # Snapshot includes source identity; the client excludes Google calendars it
    # connected directly and excludes the dedicated Etsgo output calendar.
    intervals = body.get("intervals", [])
    if len(intervals) > 10000:
        raise Problem(422, "snapshot_too_large")
    for interval in intervals:
        if parse(interval["end"]) <= parse(interval["start"]):
            raise Problem(422, "invalid_interval")
    with Session.begin() as db:
        save(db, user, "busy", "eventkit", {"intervals": intervals, "fetched_at": now().isoformat(),
             "source": "eventkit", "device_id": body["device_id"]})
    return {"saved": True}


@app.post("/v1/calendar/google/connect")
def connect(user: User):
    with Session.begin() as db:
        return {"url": calendar.google_start(db, user)}


@app.get("/v1/calendar/google/callback", response_class=HTMLResponse)
def callback(state: str, code: str):
    calendar.google_finish(state, code)
    return "<h1>Calendar connected</h1><p>You can close this window and return to Etsgo.</p>"


@app.get("/v1/calendar/status")
def calendar_status(user: User):
    with Session() as db:
        return {"google_connected": db.get(Entity, (user, "connection", "google")) is not None}


@app.post("/v1/calendar/exports")
def export(body: dict, user: User, key: Key):
    with Session.begin() as db:
        lock_account(db, user)
        previous = replay(db, user, "export:"+key, body)
        if previous:
            return previous
        actions = []
        for reference in body["sessions"]:
            row = db.get(Entity, (user, "planned", reference["id"]))
            if not row or row.deleted or row.version != reference["version"]:
                raise Problem(409, "session_stale")
            task = db.get(Entity, (user, "task", row.data["task_id"]))
            existing = db.get(Entity, (user, "binding", row.id))
            target = body["target"]
            if target not in {"google", "eventkit"}:
                raise Problem(422, "invalid_target")
            if existing and existing.data["provider"] != target:
                raise Problem(409, "already_exported_elsewhere")
            action = {"planned_id": row.id, "revision": row.version, "title": task.data["title"],
                      "start": row.data["start"], "end": row.data["end"], "device_id": body.get("device_id"),
                      "previous_start": existing.data.get("start") if existing else None,
                      "previous_end": existing.data.get("end") if existing else None,
                      "previous_etag": existing.data.get("etag") if existing else None, "action": "upsert"}
            save(db, user, "binding", row.id, {**action, "provider": target, "status": "pending"})
            if target == "google":
                if not db.get(Entity, (user, "connection", "google")):
                    raise Problem(409, "google_not_connected")
                actions.append(new_job(db, user, "calendar", action, "calendar:"+row.id+":"+str(row.version), False))
            else:
                save(db, user, "calendar_action", row.id, {**action, "status": "pending"})
                actions.append({"action_id": row.id})
        # A reschedule may remove old slots. The same explicit export approval
        # includes removing obsolete Etsgo events at the selected destination.
        for binding in entities(db, user, "binding"):
            planned = db.get(Entity, (user, "planned", binding.id))
            if not planned or not planned.deleted or binding.data["provider"] != body["target"] or binding.data.get("status") == "removed":
                continue
            action = {**binding.data, "action": "delete", "previous_etag": binding.data.get("etag"),
                      "revision": planned.version, "device_id": body.get("device_id")}
            if body["target"] == "google":
                actions.append(new_job(db, user, "calendar", action, "remove:"+binding.id+":"+str(planned.version), False))
            else:
                save(db, user, "calendar_action", binding.id, {**action, "status": "pending"})
                actions.append({"action_id": binding.id})
        return remember(db, user, "export:"+key, body, {"actions": actions})


@app.get("/v1/calendar/actions")
def calendar_actions(user: User, device_id: str):
    with Session() as db:
        return {"actions": [{"id": r.id, **r.data} for r in entities(db, user, "calendar_action")
                            if r.data["device_id"] == device_id and r.data["status"] == "pending"]}


@app.post("/v1/calendar/actions/{identity}/result")
def calendar_result(identity: str, body: dict, user: User):
    with Session.begin() as db:
        lock_account(db, user)
        row = db.get(Entity, (user, "calendar_action", identity))
        if not row or row.data["device_id"] != body.get("device_id"):
            raise Problem(404, "not_found")
        if row.data["revision"] != body.get("revision"):
            raise Problem(409, "calendar_action_stale")
        save(db, user, "calendar_action", identity, {**row.data, "status": "synced"})
        save(db, user, "binding", identity, {**row.data, "provider": "eventkit", "status": "removed" if row.data.get("action") == "delete" else "synced",
             "external_id": body["external_id"]})
    return {"saved": True}
