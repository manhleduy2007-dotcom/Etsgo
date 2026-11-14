from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import BigInteger, DateTime, Index, Integer, String, create_engine
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker

from .config import settings


def now():
    return datetime.now(UTC)


def uid():
    return str(uuid4())


class Base(DeclarativeBase):
    pass


class Account(Base):
    __tablename__ = "accounts"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    revision: Mapped[int] = mapped_column(BigInteger, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class Entity(Base):
    __tablename__ = "entities"
    owner: Mapped[str] = mapped_column(String(36), primary_key=True)
    kind: Mapped[str] = mapped_column(String(40), primary_key=True)
    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    version: Mapped[int] = mapped_column(Integer, default=1)
    data: Mapped[dict] = mapped_column(JSONB, default=dict)
    deleted: Mapped[bool] = mapped_column(default=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class Change(Base):
    __tablename__ = "changes"
    owner: Mapped[str] = mapped_column(String(36), primary_key=True)
    seq: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    body: Mapped[dict] = mapped_column(JSONB)


class Receipt(Base):
    __tablename__ = "receipts"
    owner: Mapped[str] = mapped_column(String(36), primary_key=True)
    key: Mapped[str] = mapped_column(String(150), primary_key=True)
    digest: Mapped[str] = mapped_column(String(64))
    result: Mapped[dict] = mapped_column(JSONB)


class Job(Base):
    __tablename__ = "jobs"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    owner: Mapped[str] = mapped_column(String(36), index=True)
    kind: Mapped[str] = mapped_column(String(40))
    status: Mapped[str] = mapped_column(String(30), default="queued")
    payload: Mapped[dict] = mapped_column(JSONB)
    result: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    error: Mapped[str | None] = mapped_column(String(200), nullable=True)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    lease: Mapped[str | None] = mapped_column(String(36), nullable=True)
    available_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    quota_day: Mapped[str | None] = mapped_column(String(10), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    __table_args__ = (Index("jobs_claim", "status", "available_at"),)


engine = create_engine(settings().database_url, pool_pre_ping=True)
Session = sessionmaker(engine, expire_on_commit=False)


def lock_account(db, owner):
    # INSERT ON CONFLICT permits concurrent first requests; row lock serializes
    # changes and cursor allocation only for this owner, not globally.
    from sqlalchemy.dialects.postgresql import insert
    db.execute(insert(Account).values(id=owner, revision=0).on_conflict_do_nothing())
    return db.get(Account, owner, with_for_update=True)


PUBLIC_KINDS = {"task", "context", "profile", "week", "commitment", "focus", "planned"}


def save(db, owner, kind, identity, data, deleted=False):
    account = lock_account(db, owner)
    entity = db.get(Entity, (owner, kind, identity))
    if entity is None:
        entity = Entity(owner=owner, kind=kind, id=identity, version=0)
        db.add(entity)
    entity.version += 1
    entity.data = data
    entity.deleted = deleted
    entity.updated_at = now()
    if kind in PUBLIC_KINDS:
        account.revision += 1
        db.add(Change(owner=owner, seq=account.revision, body=wire(entity)))
    db.flush()
    return entity


def wire(entity):
    return {"entity_type": entity.kind, "entity_id": entity.id,
            "version": entity.version, "payload": entity.data,
            "deleted": entity.deleted, "updated_at": entity.updated_at.isoformat()}
