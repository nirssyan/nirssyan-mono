"""Agent for synthesizing summary from extracted facts."""

from __future__ import annotations

from ..config import settings
from .base_agent import BaseJSONAgent
from .prompts import UNSEEN_SUMMARY_SYNTHESIS_PROMPT
from .schemas import SynthesisResponse


class SynthesisAgent(BaseJSONAgent[SynthesisResponse]):
    """Agent for synthesizing narrative summary from extracted facts.

    Used as Stage 2 in the two-stage summarization approach.
    """

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        super().__init__(
            response_model=SynthesisResponse,
            system_prompt=UNSEEN_SUMMARY_SYNTHESIS_PROMPT,
            human_prompt_template="Key facts from posts:\n\n{facts_content}",
            api_key=api_key or settings.unseen_summary_api_key or None,
            base_url=base_url or settings.unseen_summary_base_url or None,
            model=model or settings.unseen_summary_model,
            temperature=0.3,
        )

    async def synthesize(
        self,
        facts_content: str,
        user_id: str | None = None,
    ) -> SynthesisResponse:
        """Synthesize narrative summary from formatted facts.

        Args:
            facts_content: Formatted facts text (**Title**\n- fact1\n- fact2...)
            user_id: Optional user ID for tracking

        Returns:
            SynthesisResponse with title and summary
        """
        return await self._invoke_chain_async(
            {"facts_content": facts_content},
            "synthesize",
            user_id=user_id,
        )
