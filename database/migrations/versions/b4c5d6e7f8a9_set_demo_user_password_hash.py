"""set_demo_user_password_hash

Revision ID: b4c5d6e7f8a9
Revises: a2b3c4d5e6f7
Create Date: 2026-02-13

"""

from collections.abc import Sequence

from alembic import op

revision: str = "b4c5d6e7f8a9"
down_revision: str | None = "a2b3c4d5e6f7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

DEMO_PASSWORD_HASH = (
    "$argon2id$v=19$m=65536,t=3,p=4$fJAX3oXjLqMQwjKFasOUrA"
    "$F4hTpXuzz3up2rKH/UKHYXouCAgWi9HXDKPtkxuS8lo"
)


def upgrade() -> None:
    op.execute(
        f"UPDATE users SET password_hash = '{DEMO_PASSWORD_HASH}' "
        f"WHERE email = 'demo@infatium.ru' AND password_hash IS NULL"
    )


def downgrade() -> None:
    op.execute(
        "UPDATE users SET password_hash = NULL "
        "WHERE email = 'demo@infatium.ru'"
    )
