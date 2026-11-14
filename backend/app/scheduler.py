"""Pure scheduling rules; no LLM or database required."""
from datetime import UTC, datetime, time, timedelta
from uuid import uuid4
from zoneinfo import ZoneInfo


def parse(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(UTC)


def schedule(tasks, week, commitments, busy, timezone, start, days=14):
    import math
    start = datetime.fromtimestamp(math.ceil(start.timestamp()/300)*300, UTC)
    zone = ZoneInfo(timezone)
    today = start.astimezone(zone).date()
    windows, budgets = [], {}
    for offset in range(days):
        day = today + timedelta(days=offset)
        plan = week[day.weekday()]
        budgets[str(day)] = commitments.get(str(day), plan["commitment"])
        for window in sorted(plan["windows"], key=lambda w: w["start"]):
            base = datetime.combine(day, time(), zone)
            left = (base + timedelta(minutes=window["start"])).astimezone(UTC)
            right = (base + timedelta(minutes=window["end"])).astimezone(UTC)
            windows.append((max(left, start), right, str(day)))
    occupied = sorted((parse(b["start"]), parse(b["end"])) for b in busy)
    children = {t.get("parent_id") for t in tasks if t.get("parent_id")}
    leaves = [t for t in tasks if not t["is_done"] and t["id"] not in children]
    task_map = {t["id"]: t for t in tasks}
    # Parent grouping preserves explicit step order before priority ordering.
    def key(t):
        root = task_map.get(t.get("parent_id"), t)
        return (-{"high": 2, "medium": 1, "low": 0}[root["priority"]],
                root.get("due") or "9999", root["id"], t.get("order", 0), t["id"])
    output, unscheduled, previous, blocked = [], [], {}, set()
    for task in sorted(leaves, key=key):
        parent = task.get("parent_id")
        if parent and (parent in blocked or task_map.get(parent, {}).get("is_done")):
            unscheduled.append({"task_id": task["id"], "reason": "dependency_blocked"})
            continue
        floor = max(start, previous.get(parent, start))
        remaining = task["estimated_minutes"]
        proposed, trial_busy, trial_budget = [], list(occupied), dict(budgets)
        while remaining > 0:
            # Total estimated minutes include breaks. The final partial block
            # cannot create extra time beyond the approved remaining estimate.
            focus = min(task["focus_minutes"], remaining)
            rest = min(task["break_minutes"], max(0, remaining-focus))
            minutes = focus + rest
            found = None
            for left, right, day in windows:
                if trial_budget[day] < minutes:
                    continue
                cursor = max(left, floor)
                duration = timedelta(minutes=minutes)
                for bstart, bend in sorted(trial_busy):
                    if bend <= cursor:
                        continue
                    if bstart >= cursor + duration:
                        break
                    cursor = max(cursor, bend)
                if cursor + duration <= right:
                    found = (cursor, cursor+duration, day)
                    break
            if found is None:
                break
            begin, end, day = found
            trial_budget[day] -= minutes
            trial_busy.append((begin, end))
            proposed.append({"id": str(uuid4()), "task_id": task["id"],
                             "start": begin.isoformat(), "end": end.isoformat(),
                             "focus_minutes": focus, "break_minutes": rest})
            remaining -= minutes
            floor = end
        output.extend(proposed)
        occupied, budgets = trial_busy, trial_budget
        if parent:
            previous[parent] = floor
        if remaining:
            if parent:
                blocked.add(parent)
            unscheduled.append({"task_id": task["id"], "reason": "no_room",
                                "remaining_minutes": remaining})
    return {"sessions": output, "unscheduled": unscheduled}


def validate_sessions(sessions, tasks, week, commitments, busy, timezone, start):
    """Validate edited proposals by the same rules, without moving user slots."""
    zone = ZoneInfo(timezone)
    task_map = {t["id"]: t for t in tasks}
    used, occupied, ends = {}, [(parse(b["start"]), parse(b["end"])) for b in busy], {}
    for session in sorted(sessions, key=lambda s: s["start"]):
        task = task_map.get(session["task_id"])
        if not task or task["is_done"]:
            raise ValueError("task_changed")
        left, right = parse(session["start"]), parse(session["end"])
        minutes = session["focus_minutes"] + session["break_minutes"]
        if minutes <= 0 or right-left != timedelta(minutes=minutes) or left < start:
            raise ValueError("invalid_session_time")
        local = left.astimezone(zone)
        base = datetime.combine(local.date(), time(), zone)
        day = week[local.weekday()]
        if not any((base+timedelta(minutes=w["start"])).astimezone(UTC) <= left
                   and right <= (base+timedelta(minutes=w["end"])).astimezone(UTC) for w in day["windows"]):
            raise ValueError("outside_availability")
        if any(left < b and right > a for a, b in occupied):
            raise ValueError("calendar_conflict")
        occupied.append((left, right))
        date_key = str(local.date())
        used[date_key] = used.get(date_key, 0) + minutes
        if used[date_key] > commitments.get(date_key, day["commitment"]):
            raise ValueError("commitment_exceeded")
        ends.setdefault(task["id"], []).append((left, right))
    siblings = {}
    for task in tasks:
        if task.get("parent_id") and not task["is_done"]:
            siblings.setdefault(task["parent_id"], []).append(task)
    for group in siblings.values():
        prior_end, blocked = None, False
        for task in sorted(group, key=lambda t: (t["order"], t["id"])):
            spans = ends.get(task["id"], [])
            if spans and (blocked or (prior_end and min(a for a, _ in spans) < prior_end)):
                raise ValueError("dependency_blocked")
            if not spans or sum((b-a).total_seconds()/60 for a, b in spans) < task["estimated_minutes"]:
                blocked = True
            if spans:
                prior_end = max(b for _, b in spans)
