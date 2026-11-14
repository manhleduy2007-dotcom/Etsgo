"""Prevent direct Supabase Data API access to application tables."""
from alembic import op

revision = "0002"
down_revision = "0001"


def upgrade():
    for table in ("accounts", "entities", "changes", "receipts", "jobs"):
        op.execute(f'ALTER TABLE "{table}" ENABLE ROW LEVEL SECURITY')
        for role in ("anon", "authenticated"):
            op.execute(f"DO $$ BEGIN IF EXISTS (SELECT FROM pg_roles WHERE rolname = '{role}') THEN "
                       f'REVOKE ALL ON TABLE "{table}" FROM "{role}"; END IF; END $$;')


def downgrade():
    for table in ("accounts", "entities", "changes", "receipts", "jobs"):
        op.execute(f'ALTER TABLE "{table}" DISABLE ROW LEVEL SECURITY')
