"""create_tags_and_users_tags_tables

Revision ID: a4936a10d439
Revises: f6d2896f6ee8
Create Date: 2025-10-12 14:51:20.935845

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = "a4936a10d439"
down_revision: str | None = "f6d2896f6ee8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Create tags table
    op.create_table(
        "tags",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("name", sa.Text(), nullable=False, unique=True),
    )

    # Create users_tags table
    op.create_table(
        "users_tags",
        sa.Column(
            "id",
            sa.BigInteger(),
            primary_key=True,
            autoincrement=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("user_id", UUID(as_uuid=True), nullable=False),
        sa.Column(
            "tag_id",
            UUID(as_uuid=True),
            sa.ForeignKey("tags.id", onupdate="CASCADE", ondelete="CASCADE"),
            nullable=False,
        ),
    )

    # Create unique index on (user_id, tag_id)
    op.create_index(
        "users_tags_user_id_tag_id_uindex",
        "users_tags",
        ["user_id", "tag_id"],
        unique=True,
    )

    # Insert initial 31 tags from CHAT_MESSAGE_SYSTEM_PROMPT
    tags_to_insert = [
        "Искусственный интеллект",
        "Стартапы",
        "Кибербезопасность",
        "Web3 и криптовалюты",
        "Разработка",
        "E-commerce",
        "Маркетинг",
        "Инвестиции",
        "Предпринимательство",
        "Финтех",
        "Data Science",
        "Дизайн",
        "Product Management",
        "HR и рекрутинг",
        "Юриспруденция",
        "Журналистика",
        "Новости",
        "Блогинг",
        "Подкасты",
        "Политика",
        "Наука",
        "Образование",
        "Здоровье",
        "Экология",
        "Недвижимость",
        "Логистика",
        "Retail",
        "Производство",
        "Гейминг",
        "Путешествия",
        "Другое",
    ]

    # Bulk insert tags
    op.execute(
        sa.text(
            """
            INSERT INTO tags (name)
            VALUES
            """
            + ",\n            ".join([f"('{tag}')" for tag in tags_to_insert])
        )
    )


def downgrade() -> None:
    # Drop users_tags table (depends on tags)
    op.drop_index("users_tags_user_id_tag_id_uindex", table_name="users_tags")
    op.drop_table("users_tags")

    # Drop tags table
    op.drop_table("tags")
