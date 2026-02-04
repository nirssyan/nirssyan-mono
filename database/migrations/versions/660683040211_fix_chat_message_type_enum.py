"""fix_chat_message_type_enum

Revision ID: 660683040211
Revises: ab5b36941b7e
Create Date: 2025-10-05 12:09:34.800980

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "660683040211"
down_revision: str | None = "ab5b36941b7e"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Directly create new enum and migrate without intermediate steps
    # This avoids the "unsafe use of new value" error

    # Step 1: Create new enum type with AI and HUMAN
    op.execute("CREATE TYPE \"ChatMessageType_new\" AS ENUM ('AI', 'HUMAN')")

    # Step 2: Alter column to use new type, mapping old values to new ones
    op.execute("""
        ALTER TABLE chats_messages
        ALTER COLUMN type TYPE "ChatMessageType_new"
        USING (CASE type::text
            WHEN 'USER' THEN 'HUMAN'::\"ChatMessageType_new\"
            WHEN 'ASSISTANT' THEN 'AI'::\"ChatMessageType_new\"
            ELSE type::text::\"ChatMessageType_new\"
        END)
    """)

    # Step 3: Drop old enum and rename new one
    op.execute('DROP TYPE "ChatMessageType"')
    op.execute('ALTER TYPE "ChatMessageType_new" RENAME TO "ChatMessageType"')


def downgrade() -> None:
    # Reverse: Change enum from (AI, HUMAN) back to (USER, ASSISTANT)

    # Step 1: Create old enum type
    op.execute("CREATE TYPE \"ChatMessageType_old\" AS ENUM ('USER', 'ASSISTANT')")

    # Step 2: Update data and convert column type
    op.execute("""
        ALTER TABLE chats_messages
        ALTER COLUMN type TYPE "ChatMessageType_old"
        USING (CASE type::text
            WHEN 'HUMAN' THEN 'USER'::\"ChatMessageType_old\"
            WHEN 'AI' THEN 'ASSISTANT'::\"ChatMessageType_old\"
        END)
    """)

    # Step 3: Drop new enum and rename old one
    op.execute('DROP TYPE "ChatMessageType"')
    op.execute('ALTER TYPE "ChatMessageType_old" RENAME TO "ChatMessageType"')
