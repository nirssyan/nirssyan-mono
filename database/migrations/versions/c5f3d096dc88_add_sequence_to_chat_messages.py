"""add_sequence_to_chat_messages

Revision ID: c5f3d096dc88
Revises: 6a9834da0f90
Create Date: 2025-11-16 01:43:02.138563

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c5f3d096dc88"
down_revision: str | None = "6a9834da0f90"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "chats_messages", sa.Column("sequence", sa.BigInteger(), nullable=True)
    )

    op.execute("""
        UPDATE chats_messages
        SET sequence = row_num
        FROM (
            SELECT id, ROW_NUMBER() OVER (
                PARTITION BY chat_id
                ORDER BY created_at, id
            ) as row_num
            FROM chats_messages
        ) numbered
        WHERE chats_messages.id = numbered.id
    """)

    op.alter_column("chats_messages", "sequence", nullable=False)

    op.create_index(
        "ix_chats_messages_sequence", "chats_messages", ["chat_id", "sequence"]
    )


def downgrade() -> None:
    op.drop_index("ix_chats_messages_sequence", table_name="chats_messages")
    op.drop_column("chats_messages", "sequence")
