"""Initial account-scoped store and durable job queue."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "0001"
down_revision = None


def upgrade():
    op.create_table("accounts", sa.Column("id", sa.String(36), primary_key=True),
                    sa.Column("revision", sa.BigInteger(), nullable=False),
                    sa.Column("created_at", sa.DateTime(timezone=True), nullable=False))
    op.create_table("entities", sa.Column("owner", sa.String(36), primary_key=True),
                    sa.Column("kind", sa.String(40), primary_key=True), sa.Column("id", sa.String(100), primary_key=True),
                    sa.Column("version", sa.Integer(), nullable=False), sa.Column("data", JSONB(), nullable=False),
                    sa.Column("deleted", sa.Boolean(), nullable=False), sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False))
    op.create_table("changes", sa.Column("owner", sa.String(36), primary_key=True),
                    sa.Column("seq", sa.BigInteger(), primary_key=True), sa.Column("body", JSONB(), nullable=False))
    op.create_table("receipts", sa.Column("owner", sa.String(36), primary_key=True),
                    sa.Column("key", sa.String(150), primary_key=True), sa.Column("digest", sa.String(64), nullable=False),
                    sa.Column("result", JSONB(), nullable=False))
    op.create_table("jobs", sa.Column("id", sa.String(36), primary_key=True), sa.Column("owner", sa.String(36), nullable=False),
                    sa.Column("kind", sa.String(40), nullable=False), sa.Column("status", sa.String(30), nullable=False),
                    sa.Column("payload", JSONB(), nullable=False), sa.Column("result", JSONB()), sa.Column("error", sa.String(200)),
                    sa.Column("attempts", sa.Integer(), nullable=False), sa.Column("lease", sa.String(36)),
                    sa.Column("available_at", sa.DateTime(timezone=True), nullable=False), sa.Column("quota_day", sa.String(10)),
                    sa.Column("created_at", sa.DateTime(timezone=True), nullable=False))
    op.create_index("ix_jobs_owner", "jobs", ["owner"])
    op.create_index("jobs_claim", "jobs", ["status", "available_at"])


def downgrade():
    for table in ("jobs", "receipts", "changes", "entities", "accounts"):
        op.drop_table(table)
