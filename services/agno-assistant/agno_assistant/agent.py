from agno.agent import Agent
from agno.db.postgres import PostgresDb
from agno.models.openrouter import OpenRouter

from agno_assistant.config import settings
from agno_assistant.instructions import INSTRUCTIONS
from agno_assistant.tools.feed_discovery import (
    get_filter_suggestions,
    get_source_suggestions,
    get_view_suggestions,
    validate_source,
)
from agno_assistant.tools.feed_management import (
    create_feed,
    delete_feed,
    generate_title,
    get_feed_posts,
    list_feeds,
    read_all_posts,
    rename_feed,
    summarize_unseen,
    update_feed,
)


def create_agent() -> Agent:
    model = OpenRouter(
        id=settings.llm_model,
        api_key=settings.openrouter_api_key,
    )

    db = PostgresDb(db_url=settings.agno_database_url) if settings.database_url else None

    return Agent(
        id="infatium-assistant",
        name="Infatium Assistant",
        model=model,
        db=db,
        tools=[
            list_feeds,
            create_feed,
            update_feed,
            delete_feed,
            get_feed_posts,
            read_all_posts,
            summarize_unseen,
            rename_feed,
            generate_title,
            validate_source,
            get_view_suggestions,
            get_filter_suggestions,
            get_source_suggestions,
        ],
        instructions=INSTRUCTIONS,
        add_history_to_context=True,
        num_history_runs=5,
        update_memory_on_run=True,
        add_datetime_to_context=True,
        markdown=True,
    )
