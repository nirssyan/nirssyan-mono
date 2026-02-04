"""Agent for extracting key facts from posts."""

from __future__ import annotations

from ..config import settings
from .base_agent import BaseJSONAgent
from .prompts import FACTS_EXTRACTION_SYSTEM_PROMPT
from .schemas import FactsExtractionResponse


class FactsExtractionAgent(BaseJSONAgent[FactsExtractionResponse]):
    """Agent for extracting key facts from a batch of posts.

    Used as Stage 1 in the two-stage summarization approach.
    """

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        super().__init__(
            response_model=FactsExtractionResponse,
            system_prompt=FACTS_EXTRACTION_SYSTEM_PROMPT,
            human_prompt_template="Posts:\n\n{posts_content}",
            api_key=api_key or settings.unseen_summary_api_key or None,
            base_url=base_url or settings.unseen_summary_base_url or None,
            model=model or settings.unseen_summary_model,
            temperature=0.1,
        )

    async def extract_facts(
        self,
        posts_content: str,
        user_id: str | None = None,
    ) -> FactsExtractionResponse:
        """Extract key facts from formatted posts content.

        Args:
            posts_content: Formatted posts text (## Post 1: Title\n\nContent...)
            user_id: Optional user ID for tracking

        Returns:
            FactsExtractionResponse with list of PostFacts
        """
        return await self._invoke_chain_async(
            {"posts_content": posts_content},
            "extract_facts",
            user_id=user_id,
        )
