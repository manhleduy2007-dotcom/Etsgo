import hashlib
import json
from datetime import timedelta
from uuid import UUID, uuid5

from sqlalchemy import select

from .db import Entity, Receipt, lock_account, now, save, wire
from .schemas import KINDS


class Problem(Exception):
    def __init__(self, status, code, details=None):
        self.status, self.code, self.details = status, code, details


def digest(data):
    return hashlib.sha256(json.dumps(data, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def replay(db, owner, key, payload):
    receipt = db.get(Receipt, (owner, key))
    if receipt and receipt.digest != digest(payload):
        raise Problem(409, "idempotency_key_reused")
    return receipt.result if receipt else None


def remember(db, owner, key, payload, result):
    db.add(Receipt(owner=owner, key=key, digest=digest(payload), result=result))
    return result


def entities(db, owner, kind):
    return list(db.scalars(select(Entity).where(Entity.owner == owner, Entity.kind == kind, ~Entity.deleted)))


def singleton(db, owner, kind, fallback):
    rows = entities(db, owner, kind)
    return rows[0].data if rows else fallback


def planning_signature(db, owner):
    return digest(sorted((row.kind, row.id, row.version)
                         for kind in ("task", "context", "profile", "week", "commitment")
                         for row in entities(db, owner, kind)))


def apply(db, owner, op):
    lock_account(db, owner)
    payload = op.model_dump(mode="json")
    key = "sync:" + str(op.operation_id)
    previous = replay(db, owner, key, payload)
    if previous is not None:
        return previous
    identity = str(op.entity_id)
    current = db.get(Entity, (owner, op.entity_type, identity))
    if (current.version if current else 0) != op.expected_version or (current and current.deleted):
        return {"operation_id": str(op.operation_id), "status": "conflict",
                "current": wire(current) if current else None}
    if op.action == "delete":
        if current:
            save(db, owner, op.entity_type, identity, current.data, True)
            if op.entity_type == "task":
                descendants = [identity]
                tasks = entities(db, owner, "task")
                for parent in descendants:
                    for task in tasks:
                        if task.data.get("parent_id") == parent and task.id not in descendants:
                            descendants.append(task.id)
                            save(db, owner, "task", task.id, task.data, True)
                for planned in entities(db, owner, "planned"):
                    if planned.data["task_id"] in descendants:
                        save(db, owner, "planned", planned.id, planned.data, True)
        result = wire(current) if current else None
    else:
        data = KINDS[op.entity_type].model_validate(op.payload).model_dump(mode="json")
        if op.entity_type in {"profile", "week"}:
            other = entities(db, owner, op.entity_type)
            if other and other[0].id != identity:
                raise Problem(409, "singleton_exists", wire(other[0]))
        if op.entity_type == "task":
            parent = data.get("parent_id")
            visited = {identity}
            while parent:
                if parent in visited:
                    raise Problem(422, "task_cycle")
                visited.add(parent)
                ancestor = db.get(Entity, (owner, "task", parent))
                if not ancestor or ancestor.deleted:
                    raise Problem(409, "missing_parent")
                parent = ancestor.data.get("parent_id")
        result = wire(save(db, owner, op.entity_type, identity, data))
        if op.entity_type == "task" and data["is_done"] and data["repeat_rule"] != "none" and data["parent_id"] is None:
            copy_id = str(uuid5(UUID(identity), "next-occurrence"))
            if not db.get(Entity, (owner, "task", copy_id)):
                copy = dict(data, is_done=False)
                from datetime import datetime
                due = datetime.fromisoformat(data["due"]) if data["due"] else now()
                copy["due"] = (due + timedelta(days=1 if data["repeat_rule"] == "daily" else 7)).isoformat()
                save(db, owner, "task", copy_id, copy)
    return remember(db, owner, key, payload,
                    {"operation_id": str(op.operation_id), "status": "applied", "entity": result})
