import time
from datetime import timedelta

from sqlalchemy import select

from . import ai
from .db import Entity, Job, Session, lock_account, now, save, uid
from .sync import Problem


def execute(job, db):
    if job.kind == "calendar":
        from .calendar import export_google
        from types import SimpleNamespace
        with Session() as read_db:
            binding = read_db.get(Entity, (job.owner, "binding", job.payload["planned_id"]))
            if not binding or binding.data.get("revision") != job.payload["revision"]:
                raise Problem(409, "calendar_action_stale")
            row = read_db.get(Entity, (job.owner, "connection", "google"))
            if not row:
                raise Problem(409, "google_reconnect_required")
            connection = SimpleNamespace(data=dict(row.data))
        return export_google(connection, job.payload)
    return ai.run(job.kind, job.payload)


def process_one():
    with Session.begin() as db:
        job = db.scalar(select(Job).where(
            Job.status.in_(["queued", "running"]), Job.available_at <= now()
        ).order_by(Job.created_at).with_for_update(skip_locked=True).limit(1))
        if not job:
            return False
        if job.attempts >= 3:
            job.status, job.error = "failed", "attempts_exhausted"
            release(db, job)
            return True
        job.status, job.lease = "running", uid()
        job.attempts += 1
        job.available_at = now()+timedelta(seconds=180)
        identity, lease = job.id, job.lease
    result, error = None, None
    try:
        from types import SimpleNamespace
        with Session() as db:
            row = db.get(Job, identity)
            work = SimpleNamespace(kind=row.kind, owner=row.owner, payload=dict(row.payload))
        result = execute(work, None)
    except Exception as exc:
        # Never put provider responses, OAuth tokens or personal context in logs.
        error = exc.code if isinstance(exc, Problem) else (str(exc) if str(exc) in {
            "ai_not_configured", "ai_incomplete", "ai_authentication_failed", "ai_request_invalid"} else "provider_failed")
    with Session.begin() as db:
        job = db.get(Job, identity)
        lock_account(db, job.owner)
        if job.lease != lease or job.status != "running":
            return True
        if error:
            job.error = error
            if error == "provider_failed" and job.attempts < 3:
                job.status = "queued"
                job.available_at = now()+timedelta(seconds=2**job.attempts)
            else:
                job.status = "failed"
                release(db, job)
                if job.kind == "calendar":
                    binding = db.get(Entity, (job.owner, "binding", job.payload["planned_id"]))
                    if binding and binding.data.get("revision") == job.payload["revision"]:
                        save(db, job.owner, "binding", binding.id, {**binding.data, "status": "failed", "error": error})
            return True
        if job.kind == "plan":
            from .sync import entities, planning_signature, singleton
            unchanged = job.payload.get("input_signature") == planning_signature(db, job.owner)
            latest = str(job.payload["messages"][-1]["content"])
            from zoneinfo import ZoneInfo
            zone = ZoneInfo(singleton(db, job.owner, "profile", {"timezone": "Asia/Bangkok"})["timezone"])
            day = str(now().astimezone(zone).date())
            for fact in result.get("context_updates", []):
                if fact["evidence"] not in latest:
                    continue
                scope = fact["scope"]
                scope_id = day if scope == "day" else (job.payload["conversation_id"] if scope == "conversation" else None)
                if not any(f.data["text"].casefold() == fact["text"].casefold() and f.data["scope_id"] == scope_id
                           for f in entities(db, job.owner, "context")):
                    save(db, job.owner, "context", uid(), {"text": fact["text"], "source": "user", "confirmed": True,
                         "scope": scope, "scope_id": scope_id, "valid_until": None})
            conversation = db.get(Entity, (job.owner, "conversation", job.payload["conversation_id"]))
            data = dict(conversation.data)
            data["messages"] = data["messages"] + [{"role": "assistant", "content": result}]
            save(db, job.owner, "conversation", conversation.id, data)
            if result["type"] == "plan":
                proposal = save(db, job.owner, "proposal", uid(), {"type": "plan", "status": "draft" if unchanged else "stale", "turn": result,
                                "conversation_id": conversation.id, "input_signature": planning_signature(db, job.owner)})
                result = {**result, "proposal_id": proposal.id, "proposal_version": proposal.version}
        if job.kind == "handoff":
            for fact in result["items"]:
                # Exact duplicate imports are coalesced; conflicting facts stay separate for review.
                from .sync import entities
                if not any(f.data["text"].casefold() == fact["text"].casefold() for f in entities(db, job.owner, "context")):
                    save(db, job.owner, "context", uid(), {"text": fact["text"], "source": "handoff" if fact["stated"] else "assumption",
                         "confirmed": False, "scope": "personal", "scope_id": None, "valid_until": None})
        if job.kind == "calendar":
            binding = db.get(Entity, (job.owner, "binding", job.payload["planned_id"]))
            if binding and binding.data.get("revision") != job.payload["revision"]:
                job.status = "cancelled"
                return True
            save(db, job.owner, "binding", job.payload["planned_id"], {**job.payload, **result, "provider": "google",
                 "status": "removed" if result.get("removed") else "synced"})
        job.status, job.result, job.error = "succeeded", result, None
    return True


def release(db, job):
    if not job.quota_day:
        return
    quota = db.get(Entity, (job.owner, "quota", job.quota_day))
    if quota:
        quota.data = {"used": max(0, quota.data["used"]-1)}
    job.quota_day = None


def main():
    while True:
        try:
            if not process_one():
                time.sleep(1)
        except Exception:
            import logging
            logging.getLogger("etsgo.worker").error("Worker cycle failed; retrying (details suppressed)")
            time.sleep(2)


if __name__ == "__main__":
    main()
