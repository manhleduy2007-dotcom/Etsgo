from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import httpx
from sqlalchemy import select

from app.db import Entity, Job, Session
from app.main import new_job
from app.schemas import TaskData
from app.scheduler import schedule, validate_sessions
from app.worker import process_one

REAL_HTTPX_CLIENT = httpx.Client


def operation(kind="task", payload=None, identity=None, version=0, action="upsert"):
    return {"operation_id": str(uuid4()), "entity_type": kind, "entity_id": identity or str(uuid4()),
            "action": action, "expected_version": version,
            "payload": payload or TaskData(title="Learn Python").model_dump(mode="json")}


def push(client, headers, op):
    result = client.post("/v1/sync/push", headers=headers, json={"operations": [op]})
    assert result.status_code == 200, result.text
    return result.json()["results"][0]


def test_auth_and_owner_isolation(client, user):
    _, headers = user
    assert client.get("/v1/me").status_code == 401
    assert client.get("/v1/me", headers=headers).status_code == 200
    push(client, headers, operation())
    assert len(client.get("/v1/sync/pull", headers=headers).json()["changes"]) == 1
    other = dict(headers, Authorization="Bearer invalid")
    assert client.get("/v1/sync/pull", headers=other).status_code == 401


def test_replay_and_conflict(client, user):
    _, headers = user
    op = operation()
    first = push(client, headers, op)
    assert push(client, headers, op) == first
    assert first["entity"]["version"] == 1
    changed = dict(op, payload={"title": "Another title"})
    assert push(client, headers, changed)["code"] == "idempotency_key_reused"
    stale = operation(identity=op["entity_id"])
    assert push(client, headers, stale)["status"] == "conflict"
    assert len(client.get("/v1/sync/pull", headers=headers).json()["changes"]) == 1


def test_child_order_cycle_and_cascade(client, user):
    _, headers = user
    parent = operation()
    child = operation(payload={"title": "Step", "parent_id": parent["entity_id"]})
    assert push(client, headers, child)["code"] == "missing_parent"
    push(client, headers, parent)
    assert push(client, headers, child)["status"] == "applied"
    cyclic = operation(identity=parent["entity_id"], version=1,
                       payload={"title": "Parent", "parent_id": child["entity_id"]})
    assert push(client, headers, cyclic)["code"] == "task_cycle"
    push(client, headers, operation(identity=parent["entity_id"], version=1, action="delete"))
    changes = client.get("/v1/sync/pull", headers=headers).json()["changes"]
    assert sum(c["deleted"] for c in changes) == 2
    assert push(client, headers, operation(identity=child["entity_id"], version=2))["status"] == "conflict"


def test_pagination_snapshot_concurrent_write(client, user):
    _, headers = user
    for _ in range(3):
        push(client, headers, operation())
    page = client.get("/v1/sync/pull?limit=1", headers=headers).json()
    push(client, headers, operation())
    cursor, boundary = page["cursor"], page["until"]
    seen = list(page["changes"])
    while cursor < boundary:
        page = client.get(f"/v1/sync/pull?limit=1&cursor={cursor}&until={boundary}", headers=headers).json()
        seen += page["changes"]
        cursor = page["cursor"]
    assert len(seen) == 3
    assert len(client.get(f"/v1/sync/pull?cursor={cursor}", headers=headers).json()["changes"]) == 1


def test_concurrent_versions_serialized(client, user):
    _, headers = user
    initial = operation()
    push(client, headers, initial)
    def edit(i):
        return push(client, headers, operation(identity=initial["entity_id"], version=1, payload={"title": str(i)}))["status"]
    with ThreadPoolExecutor(2) as pool:
        results = list(pool.map(edit, range(2)))
    assert sorted(results) == ["applied", "conflict"]


def test_recurrence_idempotent(client, user):
    _, headers = user
    op = operation(payload={"title": "Daily", "repeat_rule": "daily", "is_done": True})
    push(client, headers, op)
    push(client, headers, op)
    changes = client.get("/v1/sync/pull", headers=headers).json()["changes"]
    assert len(changes) == 2


def test_plan_job_persist_accept_once(client, user, monkeypatch):
    owner, headers = user
    created = client.post("/v1/conversations", headers={**headers, "Idempotency-Key": str(uuid4())}).json()
    turn = {"type": "plan", "message": "Start here", "title": "Python", "quick_replies": [],
            "steps": [{"title": "Run Python", "estimated_minutes": 30, "focus_minutes": 25, "break_minutes": 5}],
            "later": [], "based_on": [], "assumptions": []}
    monkeypatch.setattr("app.worker.execute", lambda job, db: turn)
    key = str(uuid4())
    response = client.post(f"/v1/conversations/{created['id']}/messages", headers={**headers, "Idempotency-Key": key},
                           json={"text": "Learn Python"})
    assert response.status_code == 202
    identity = response.json()["job_id"]
    # Process only this job in the isolated test database queue.
    for _ in range(20):
        process_one()
        job = client.get("/v1/jobs/"+identity, headers=headers).json()
        if job["status"] == "succeeded":
            break
    assert job["status"] == "succeeded"
    result = job["result"]
    body = {"expected_version": result["proposal_version"]}
    accept_headers = {**headers, "Idempotency-Key": "accept-"+identity}
    url = "/v1/proposals/"+result["proposal_id"]+"/accept"
    assert client.post(url, headers=accept_headers, json=body).status_code == 200
    assert client.post(url, headers=accept_headers, json=body).status_code == 200
    with Session() as db:
        assert len(list(db.scalars(select(Entity).where(Entity.owner == owner, Entity.kind == "task")))) == 2
    assert client.get(f"/v1/conversations/{created['id']}", headers=headers).json()["messages"][-1]["role"] == "assistant"


def test_quota_atomic_and_failure_refund(client, user, monkeypatch):
    owner, headers = user
    monkeypatch.setattr("app.main.settings", lambda: type("Config", (), {"daily_ai_limit": 1})())
    with Session.begin() as db:
        first = new_job(db, owner, "guidance", {}, "test")
    def fail(job, db):
        raise RuntimeError("ai_not_configured")
    monkeypatch.setattr("app.worker.execute", fail)
    for _ in range(20):
        process_one()
        if client.get("/v1/jobs/"+first["job_id"], headers=headers).json()["status"] == "failed":
            break
    with Session() as db:
        job = db.get(Job, first["job_id"])
        assert job.status == "failed"
        quota = db.get(Entity, (owner, "quota", str(datetime.now(UTC).date())))
        assert quota.data["used"] == 0


def test_focus_validation(client, user):
    _, headers = user
    end = datetime.now(UTC)
    op = operation("focus", {"task_title": "Python", "started_at": (end-timedelta(seconds=10)).isoformat(),
                            "finished_at": end.isoformat(), "focus_seconds": 100})
    assert push(client, headers, op)["code"] == "invalid_payload"


def inputs(minutes=120, commitment=60):
    start = datetime(2026, 11, 16, 8, tzinfo=UTC)
    week = [{"windows": [{"start": 540, "end": 720}], "commitment": commitment} for _ in range(7)]
    task = {**TaskData(title="Learn", estimated_minutes=minutes).model_dump(mode="json"), "id": str(uuid4())}
    return start, week, task


def test_scheduler_splits_and_respects_budget():
    start, week, task = inputs()
    output = schedule([task], week, {}, [], "UTC", start)
    assert len(output["sessions"]) == 4
    totals = {}
    for entry in output["sessions"]:
        day = entry["start"][:10]
        totals[day] = totals.get(day, 0)+entry["focus_minutes"]+entry["break_minutes"]
    assert max(totals.values()) <= 60
    validate_sessions(output["sessions"], [task], week, {}, [], "UTC", start)


def test_scheduler_blocked_dependency():
    start, week, first = inputs(120, 0)
    parent = str(uuid4())
    first.update(parent_id=parent, order=0)
    second = {**first, "id": str(uuid4()), "order": 1, "estimated_minutes": 15}
    output = schedule([first, second], week, {}, [], "UTC", start)
    assert not output["sessions"]
    assert output["unscheduled"][1]["reason"] == "dependency_blocked"


def test_scheduler_busy_and_edited_invalid():
    start, week, task = inputs(30)
    busy = [{"start": "2026-11-16T09:00:00Z", "end": "2026-11-16T10:00:00Z"}]
    output = schedule([task], week, {}, busy, "UTC", start)
    assert output["sessions"][0]["start"].startswith("2026-11-16T10:")
    import pytest
    with pytest.raises(ValueError, match="calendar_conflict"):
        validate_sessions(output["sessions"], [task], week, {}, [
            {"start": output["sessions"][0]["start"], "end": output["sessions"][0]["end"]}], "UTC", start)


def test_other_user_cannot_read_job(client, user):
    _, headers = user
    with Session.begin() as db:
        result = new_job(db, str(uuid4()), "guidance", {}, "private")
    assert client.get("/v1/jobs/"+result["job_id"], headers=headers).status_code == 404


def test_google_selection_validates_and_invalidates_snapshot(client, user, monkeypatch):
    from app.db import save
    owner, headers = user
    with Session.begin() as db:
        row = save(db, owner, "connection", "google", {"refresh": "secret-not-exposed", "app_calendar": "own", "read_calendars": ["primary"]})
        version = row.version
        save(db, owner, "busy", "google", {"intervals": [], "fetched_at": datetime.now(UTC).isoformat()})
    monkeypatch.setattr("app.calendar.google_calendars", lambda owner: ([{"id": "a", "title": "Classes", "selected": False}], version))
    url = "/v1/calendar/google/calendars"
    assert client.put(url, headers=headers, json={"calendar_ids": ["unavailable"], "expected_version": version}).status_code == 422
    response = client.put(url, headers=headers, json={"calendar_ids": ["a"], "expected_version": version})
    assert response.status_code == 200
    assert client.put(url, headers=headers, json={"calendar_ids": [], "expected_version": version}).status_code == 409
    with Session() as db:
        assert db.get(Entity, (owner, "busy", "google")).data["disabled"] is True
    status = client.get("/v1/calendar/status", headers=headers).json()
    assert "secret-not-exposed" not in str(status)


def test_eventkit_failure_and_revision(client, user):
    from app.db import save
    owner, headers = user
    identity = str(uuid4())
    with Session.begin() as db:
        save(db, owner, "calendar_action", identity, {"device_id": "phone", "revision": 2, "status": "pending"})
    url = "/v1/calendar/actions/"+identity+"/result"
    assert client.post(url, headers=headers, json={"device_id": "phone", "revision": 1, "status": "failed"}).status_code == 409
    assert client.post(url, headers=headers, json={"device_id": "other", "revision": 2, "status": "failed"}).status_code == 404
    assert client.post(url, headers=headers, json={"device_id": "phone", "revision": 2, "status": "failed"}).status_code == 200
    status = client.get("/v1/calendar/status", headers=headers).json()
    assert status["exports"][0]["status"] == "failed"


def test_google_list_paginates_and_excludes_output(user, monkeypatch):
    import httpx
    from app import calendar
    from app.db import save
    owner, _ = user
    with Session.begin() as db:
        save(db, owner, "connection", "google", {"app_calendar": "own", "read_calendars": ["primary"]})
    monkeypatch.setattr(calendar, "google_token", lambda connection: "test-token")
    original = httpx.Client
    def handler(request):
        if request.url.params.get("pageToken"):
            return httpx.Response(200, json={"items": [{"id": "b", "summary": "School"}, {"id": "own"}]})
        return httpx.Response(200, json={"items": [{"id": "a", "primary": True}], "nextPageToken": "next"})
    monkeypatch.setattr(calendar.httpx, "Client", lambda **kwargs: original(transport=httpx.MockTransport(handler), **kwargs))
    rows, _ = calendar.google_calendars(owner)
    assert [row["id"] for row in rows] == ["a", "b"]
    assert rows[0]["selected"] is True


def test_google_create_race_rejects_mismatched_event(monkeypatch):
    import httpx
    import pytest
    from types import SimpleNamespace
    from app import calendar
    from app.sync import Problem
    monkeypatch.setattr(calendar, "google_token", lambda connection: "test-token")
    original = httpx.Client
    count = 0
    def handler(request):
        nonlocal count
        count += 1
        if count == 1:
            return httpx.Response(404)
        if request.method == "POST":
            return httpx.Response(409)
        return httpx.Response(200, json={"extendedProperties": {"private": {"etsgo_id": "other"}}})
    monkeypatch.setattr(calendar.httpx, "Client", lambda **kwargs: original(transport=httpx.MockTransport(handler), **kwargs))
    with pytest.raises(Problem) as error:
        calendar.export_google(SimpleNamespace(data={"app_calendar": "own"}), {"planned_id": str(uuid4()), "revision": 1,
            "title": "Study", "start": "2026-11-16T09:00:00Z", "end": "2026-11-16T09:30:00Z"})
    assert error.value.code == "calendar_reconcile_required"


def test_schedule_accept_export_and_stale_ack(client, user):
    _, headers = user
    push(client, headers, operation("profile", {"timezone": "UTC", "language": "en"}))
    push(client, headers, operation("week", {"days": [
        {"windows": [{"start": 0, "end": 1440}], "commitment": 60} for _ in range(7)]}))
    push(client, headers, operation())
    def propose_and_accept():
        response = client.post("/v1/schedule/proposals", headers={**headers, "Idempotency-Key": str(uuid4())})
        assert response.status_code == 200, response.text
        value = response.json()
        assert value["sessions"]
        response = client.post("/v1/proposals/"+value["id"]+"/accept", headers={**headers, "Idempotency-Key": str(uuid4())},
                               json={"expected_version": value["version"]})
        assert response.status_code == 200, response.text
        changes = client.get("/v1/sync/pull", headers=headers).json()["changes"]
        current = {}
        for change in changes:
            if change["entity_type"] == "planned":
                current[change["entity_id"]] = change
        return [{"id": item["entity_id"], "version": item["version"]} for item in current.values() if not item["deleted"]]
    first = propose_and_accept()
    body = {"sessions": first, "target": "eventkit", "device_id": "phone"}
    for _ in range(2):
        assert client.post("/v1/calendar/exports", headers={**headers, "Idempotency-Key": str(uuid4())}, json=body).status_code == 200
    second = propose_and_accept()
    assert second[0]["id"] == first[0]["id"]
    assert second[0]["version"] > first[0]["version"]
    body["sessions"] = second
    assert client.post("/v1/calendar/exports", headers={**headers, "Idempotency-Key": str(uuid4())}, json=body).status_code == 200
    response = client.post("/v1/calendar/actions/"+first[0]["id"]+"/result", headers=headers,
                           json={"device_id": "phone", "revision": first[0]["version"], "external_id": "old"})
    assert response.status_code == 409


def openai_settings(**overrides):
    from app.config import Settings
    values = {"ai_provider": "openai", "openai_api_key": "test-key", "ai_model": "test-model", "_env_file": None}
    return Settings(**{**values, **overrides})


def mock_openai(monkeypatch, handler):
    import httpx
    from app import ai
    monkeypatch.setattr(ai.httpx, "Client",
                        lambda **kwargs: REAL_HTTPX_CLIENT(transport=httpx.MockTransport(handler), **kwargs))


def test_openai_responses_adapter_parses_and_prunes(monkeypatch):
    import json
    import httpx
    from app import ai
    from app.schemas import PlanTurn
    seen = {}
    def handler(request):
        seen.update(path=request.url.path, body=json.loads(request.content), auth=request.headers["Authorization"])
        turn = {"type": "question", "message": "Level?", "quick_replies": ["New"], "unexpected": 1}
        return httpx.Response(200, json={"status": "completed", "output": [
            {"type": "reasoning", "summary": []},
            {"type": "message", "content": [{"type": "output_text", "text": "```json\n" + json.dumps(turn) + "\n```"}]}]})
    monkeypatch.setattr(ai, "settings", lambda: openai_settings())
    mock_openai(monkeypatch, handler)
    result = ai.complete(PlanTurn, "rule", {"messages": []})
    assert result["type"] == "question" and result["quick_replies"] == ["New"] and "unexpected" not in result
    assert seen["path"] == "/v1/responses" and seen["auth"] == "Bearer test-key"
    assert seen["body"]["model"] == "test-model" and seen["body"]["text"]["format"]["type"] == "json_object"


def test_openai_chat_style_and_error_codes(monkeypatch):
    import httpx
    import pytest
    from app import ai
    from app.schemas import PlanTurn
    monkeypatch.setattr(ai, "settings", lambda: openai_settings(openai_api_style="chat"))
    mock_openai(monkeypatch, lambda request: httpx.Response(200, json={"choices": [
        {"finish_reason": "stop", "message": {"content": '{"type": "question", "message": "Hi"}'}}]}))
    assert ai.complete(PlanTurn, "rule", {})["message"] == "Hi"
    for status, code, expected, retry in [(401, "expired_secret_key", "ai_auth_failed", False),
                                          (404, "model_not_found", "ai_model_unavailable", False),
                                          (429, "insufficient_quota", "ai_provider_quota_exhausted", False),
                                          (429, "rate_limit_exceeded", "ai_rate_limited", True),
                                          (500, "", "provider_failed", True)]:
        mock_openai(monkeypatch, lambda request, s=status, c=code: httpx.Response(s, json={"error": {"code": c}}))
        with pytest.raises(ai.AIFailure) as error:
            ai.complete(PlanTurn, "rule", {})
        assert (error.value.code, error.value.retryable) == (expected, retry)
    monkeypatch.setattr(ai, "settings", lambda: openai_settings(openai_api_key=""))
    with pytest.raises(ai.AIFailure) as error:
        ai.complete(PlanTurn, "rule", {})
    assert error.value.code == "ai_not_configured"


def test_expired_ai_key_fails_once_and_refunds_quota(client, user, monkeypatch):
    import httpx
    from app import ai
    owner, headers = user
    monkeypatch.setattr(ai, "settings", lambda: openai_settings())
    mock_openai(monkeypatch, lambda request: httpx.Response(401, json={"error": {"code": "expired_secret_key"}}))
    response = client.post("/v1/ai/parse", headers={**headers, "Idempotency-Key": str(uuid4())}, json={"text": "Math"})
    assert response.status_code == 202
    identity = response.json()["job_id"]
    for _ in range(50):
        process_one()
        job = client.get("/v1/jobs/"+identity, headers=headers).json()
        if job["status"] == "failed":
            break
    assert job == {"id": identity, "status": "failed", "result": None, "error": "ai_auth_failed"}
    with Session() as db:
        assert db.get(Job, identity).attempts == 1
        assert db.get(Entity, (owner, "quota", str(datetime.now(UTC).date()))).data["used"] == 0


def test_deleting_cascaded_child_is_not_a_conflict(client, user):
    _, headers = user
    parent = operation()
    child = operation(payload={"title": "Step", "parent_id": parent["entity_id"]})
    push(client, headers, parent)
    push(client, headers, child)
    assert push(client, headers, operation(identity=parent["entity_id"], version=1, action="delete"))["status"] == "applied"
    result = push(client, headers, operation(identity=child["entity_id"], version=1, action="delete"))
    assert result["status"] == "applied" and result["entity"]["deleted"] is True
    # Editing a deleted record is still a conflict; deleted data is never restored implicitly.
    assert push(client, headers, operation(identity=child["entity_id"], version=2))["status"] == "conflict"


def test_schedule_accept_tolerates_first_slot_passing(client, user, monkeypatch):
    _, headers = user
    push(client, headers, operation("profile", {"timezone": "UTC", "language": "en"}))
    push(client, headers, operation("week", {"days": [
        {"windows": [{"start": 0, "end": 1440}], "commitment": 600} for _ in range(7)]}))
    push(client, headers, operation())
    value = client.post("/v1/schedule/proposals", headers={**headers, "Idempotency-Key": str(uuid4())}).json()
    assert "calendar_not_connected" in value["warnings"]
    import app.main
    later = datetime.now(UTC) + timedelta(minutes=6)
    monkeypatch.setattr(app.main, "now", lambda: later)
    response = client.post("/v1/proposals/"+value["id"]+"/accept", headers={**headers, "Idempotency-Key": str(uuid4())},
                           json={"expected_version": value["version"]})
    assert response.status_code == 200, response.text
