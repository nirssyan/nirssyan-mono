"""create_prompt_examples_tables

Revision ID: f70501d09c52
Revises: a4936a10d439
Create Date: 2025-10-12 16:55:31.977919

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = "f70501d09c52"
down_revision: str | None = "a4936a10d439"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Create prompt_examples table
    op.create_table(
        "prompt_examples",
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
        sa.Column("prompt", sa.Text(), nullable=False),
    )

    # Create prompt_examples_tags junction table
    op.create_table(
        "prompt_examples_tags",
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
        sa.Column(
            "prompt_example_id",
            UUID(as_uuid=True),
            sa.ForeignKey("prompt_examples.id", onupdate="CASCADE", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "tag_id",
            UUID(as_uuid=True),
            sa.ForeignKey("tags.id", onupdate="CASCADE", ondelete="CASCADE"),
            nullable=False,
        ),
    )

    # Create unique index on (prompt_example_id, tag_id)
    op.create_index(
        "prompt_examples_tags_prompt_example_id_tag_id_uindex",
        "prompt_examples_tags",
        ["prompt_example_id", "tag_id"],
        unique=True,
    )

    # Seed prompt examples for each tag
    conn = op.get_bind()

    # Define prompts for each tag (tag_name -> prompt_text)
    tag_prompts = {
        "Искусственный интеллект": "Отфильтруй посты про машинное обучение, нейросети, LLM и AI-инструменты для разработки",
        "Стартапы": "Покажи новости о запусках продуктов, привлечении инвестиций и успешных кейсах стартапов",
        "Кибербезопасность": "Выбери материалы про уязвимости, защиту данных, хакерские атаки и best practices безопасности",
        "Web3 и криптовалюты": "Фильтруй контент про блокчейн-проекты, DeFi, NFT и криптовалютные новости",
        "Разработка": "Отбери статьи про языки программирования, фреймворки, инструменты разработки и архитектурные паттерны",
        "E-commerce": "Покажи посты про онлайн-торговлю, маркетплейсы, конверсию и инструменты для e-commerce",
        "Маркетинг": "Выбери контент про digital-маркетинг, SMM-стратегии, рекламные кампании и аналитику",
        "Инвестиции": "Фильтруй материалы про венчурные инвестиции, фондовый рынок и финансовые стратегии роста",
        "Предпринимательство": "Отбери посты про бизнес-стратегии, управление компанией и масштабирование бизнеса",
        "Финтех": "Покажи новости про финансовые технологии, платежные системы и банковские инновации",
        "Data Science": "Выбери статьи про анализ данных, визуализацию, big data и ML-модели",
        "Дизайн": "Фильтруй контент про UI/UX дизайн, графический дизайн и продуктовый дизайн",
        "Product Management": "Отбери материалы про управление продуктом, метрики, prioritization и product roadmap",
        "HR и рекрутинг": "Покажи посты про найм специалистов, развитие команды и современные HR-практики",
        "Юриспруденция": "Выбери контент про правовые аспекты IT-бизнеса, договоры и регуляторные требования",
        "Журналистика": "Фильтруй материалы про медиа-индустрию, новостные форматы и журналистские расследования",
        "Новости": "Отбери актуальные новостные сводки и важные события дня",
        "Блогинг": "Покажи посты про создание блогов, контент-стратегии и монетизацию контента",
        "Подкасты": "Выбери контент про подкастинг, производство аудио и интересные интервью",
        "Политика": "Фильтруй материалы про политические события, законодательство и выборы",
        "Наука": "Отбери посты про научные открытия, исследования и прорывные технологии",
        "Образование": "Покажи контент про онлайн-обучение, образовательные курсы и EdTech-платформы",
        "Здоровье": "Выбери материалы про медицинские инновации, wellness и здоровый образ жизни",
        "Экология": "Фильтруй посты про устойчивое развитие, зеленые технологии и борьбу с изменением климата",
        "Недвижимость": "Отбери контент про рынок недвижимости, инвестиции в недвижимость и строительные проекты",
        "Логистика": "Покажи материалы про цепи поставок, складскую логистику и оптимизацию доставки",
        "Retail": "Выбери посты про розничную торговлю, ритейл-технологии и управление торговыми сетями",
        "Производство": "Фильтруй контент про промышленное производство, автоматизацию и Industry 4.0",
        "Гейминг": "Отбери материалы про видеоигры, игровую индустрию, киберспорт и game development",
        "Путешествия": "Покажи посты про туризм, путешествия и инновации в travel-индустрии",
        "Другое": "Фильтруй интересный и качественный контент, который не попадает в основные категории",
    }

    # Insert prompts and link them to tags
    for tag_name, prompt_text in tag_prompts.items():
        # Get tag id
        tag_result = conn.execute(
            sa.text("SELECT id FROM tags WHERE name = :tag_name"),
            {"tag_name": tag_name},
        )
        tag_row = tag_result.fetchone()

        if tag_row:
            tag_id = tag_row[0]

            # Insert prompt example
            prompt_result = conn.execute(
                sa.text(
                    "INSERT INTO prompt_examples (prompt) VALUES (:prompt) RETURNING id"
                ),
                {"prompt": prompt_text},
            )
            prompt_id = prompt_result.fetchone()[0]

            # Link prompt to tag
            conn.execute(
                sa.text(
                    "INSERT INTO prompt_examples_tags (prompt_example_id, tag_id) VALUES (:prompt_id, :tag_id)"
                ),
                {"prompt_id": prompt_id, "tag_id": tag_id},
            )


def downgrade() -> None:
    # Drop prompt_examples_tags table (depends on prompt_examples)
    op.drop_index(
        "prompt_examples_tags_prompt_example_id_tag_id_uindex",
        table_name="prompt_examples_tags",
    )
    op.drop_table("prompt_examples_tags")

    # Drop prompt_examples table
    op.drop_table("prompt_examples")
