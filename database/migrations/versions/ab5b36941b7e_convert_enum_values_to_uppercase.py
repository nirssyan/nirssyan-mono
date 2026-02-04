"""convert_enum_values_to_uppercase

Revision ID: ab5b36941b7e
Revises: 23d1abc38f2e
Create Date: 2025-09-27 11:50:51.400294

"""

from collections.abc import Sequence

# revision identifiers, used by Alembic.
revision: str = "ab5b36941b7e"
down_revision: str | None = "23d1abc38f2e"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # This migration documents the change to use UPPERCASE enum names in code
    # while maintaining lowercase database values for compatibility
    # The enum classes now use uppercase constant names (e.g., FeedType.RSS)
    # but still store lowercase values in the database (e.g., "rss")
    pass


def downgrade() -> None:
    # This is a code-level change, no database changes to revert
    pass
