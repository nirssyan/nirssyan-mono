"""Agent for summarizing unseen posts into a digest."""

from __future__ import annotations

import asyncio
from typing import Any

from loguru import logger

from ..config import settings
from .base_agent import BaseJSONAgent
from .facts_extraction_agent import FactsExtractionAgent
from .prompts import UNSEEN_SUMMARY_SYSTEM_PROMPT
from .schemas import SynthesisResponse, UnseenSummaryResponse
from .synthesis_agent import SynthesisAgent

BATCH_SIZE = 10


class UnseenSummaryAgent(BaseJSONAgent[UnseenSummaryResponse]):
    """Agent for creating digests from unseen posts."""

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        super().__init__(
            response_model=UnseenSummaryResponse,
            system_prompt=UNSEEN_SUMMARY_SYSTEM_PROMPT,
            human_prompt_template="Posts to summarize:\n\n{posts_content}",
            api_key=api_key or settings.unseen_summary_api_key or None,
            base_url=base_url or settings.unseen_summary_base_url or None,
            model=model or settings.unseen_summary_model,
            temperature=0.3,
        )
        self._facts_agent: FactsExtractionAgent | None = None
        self._synthesis_agent: SynthesisAgent | None = None

    def _get_facts_agent(self) -> FactsExtractionAgent:
        """Lazy initialization of facts extraction agent."""
        if self._facts_agent is None:
            self._facts_agent = FactsExtractionAgent(
                api_key=self.api_key,
                base_url=self.base_url,
                model=self.model,
            )
        return self._facts_agent

    def _get_synthesis_agent(self) -> SynthesisAgent:
        """Lazy initialization of synthesis agent."""
        if self._synthesis_agent is None:
            self._synthesis_agent = SynthesisAgent(
                api_key=self.api_key,
                base_url=self.base_url,
                model=self.model,
            )
        return self._synthesis_agent

    async def summarize_unseen(
        self,
        posts_data: list[dict],
        user_id: str | None = None,
    ) -> UnseenSummaryResponse:
        """Summarize unseen posts using optimized two-stage approach.

        Stage 1: Extract key facts from posts (parallel batches)
        Stage 2: Synthesize narrative summary from facts
        Stage 3: Compose full_text programmatically (no LLM)
        """
        if len(posts_data) <= 5:
            return await self._summarize_single_stage(posts_data, user_id)

        return await self._summarize_two_stage(posts_data, user_id)

    async def _summarize_single_stage(
        self,
        posts_data: list[dict],
        user_id: str | None = None,
    ) -> UnseenSummaryResponse:
        """Original single-stage approach for small post counts."""
        formatted_posts = []
        for i, post in enumerate(posts_data, 1):
            title = post.get("title") or f"Post {i}"
            content = post.get("content", "")
            formatted_posts.append(f"## {title}\n\n{content}")

        combined = "\n\n---\n\n".join(formatted_posts)

        return await self._invoke_chain_async(
            {"posts_content": combined},
            "summarize_unseen",
            user_id=user_id,
        )

    async def _summarize_two_stage(
        self,
        posts_data: list[dict],
        user_id: str | None = None,
    ) -> UnseenSummaryResponse:
        """Optimized two-stage approach for larger post counts."""
        logger.info(f"Starting two-stage summarization for {len(posts_data)} posts")

        try:
            facts = await self._extract_facts_parallel(posts_data, user_id)
            synthesis = await self._synthesize_from_facts(facts, user_id)
        except Exception as e:
            logger.warning(f"Two-stage failed, falling back to single-stage: {e}")
            return await self._summarize_single_stage(posts_data, user_id)

        full_text = self._compose_full_text(posts_data)

        return UnseenSummaryResponse(
            title=synthesis.title,
            summary=synthesis.summary,
            full_text=full_text,
        )

    async def _extract_facts_parallel(
        self,
        posts_data: list[dict],
        user_id: str | None = None,
    ) -> list[dict[str, Any]]:
        """Extract facts from posts in parallel batches."""
        batches = [
            posts_data[i : i + BATCH_SIZE]
            for i in range(0, len(posts_data), BATCH_SIZE)
        ]

        logger.debug(f"Extracting facts from {len(batches)} batches")

        tasks = [
            self._extract_facts_batch(batch, batch_idx, user_id)
            for batch_idx, batch in enumerate(batches)
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)

        all_facts = []
        for batch_idx, result in enumerate(results):
            if isinstance(result, Exception):
                logger.error(f"Batch {batch_idx} failed: {result}")
                continue
            all_facts.extend(result)

        return all_facts

    async def _extract_facts_batch(
        self,
        batch: list[dict],
        batch_idx: int,
        user_id: str | None = None,
    ) -> list[dict[str, Any]]:
        """Extract facts from a single batch of posts using FactsExtractionAgent."""
        formatted_posts = []
        for i, post in enumerate(batch, 1):
            title = post.get("title") or f"Post {i}"
            content = post.get("content", "")
            formatted_posts.append(f"## Post {i}: {title}\n\n{content}")

        combined = "\n\n---\n\n".join(formatted_posts)

        try:
            response = await self._get_facts_agent().extract_facts(
                posts_content=combined,
                user_id=user_id,
            )
            return [
                {"title": pf.title, "topic": pf.topic, "facts": pf.facts}
                for pf in response.posts
            ]

        except Exception as e:
            logger.error(f"Error extracting facts from batch {batch_idx}: {e}")
            raise

    async def _synthesize_from_facts(
        self,
        facts: list[dict[str, Any]],
        user_id: str | None = None,
    ) -> SynthesisResponse:
        """Synthesize narrative summary from extracted facts using SynthesisAgent."""
        facts_text = []
        for i, fact_item in enumerate(facts, 1):
            title = fact_item.get("title", f"Topic {i}")
            topic = fact_item.get("topic", "")
            fact_list = fact_item.get("facts", [])
            facts_str = "\n".join(f"- {f}" for f in fact_list)
            topic_label = f" [topic: {topic}]" if topic else ""
            facts_text.append(f"**{title}**{topic_label}\n{facts_str}")

        combined_facts = "\n\n".join(facts_text)

        try:
            return await self._get_synthesis_agent().synthesize(
                facts_content=combined_facts,
                user_id=user_id,
            )

        except Exception as e:
            logger.error(f"Error in synthesis stage: {e}")
            raise ValueError(f"Synthesis stage failed: {e}") from e

    def _compose_full_text(self, posts_data: list[dict]) -> str:
        """Compose full_text programmatically without LLM."""
        formatted_posts = []
        for i, post in enumerate(posts_data, 1):
            title = post.get("title") or f"Post {i}"
            content = post.get("content", "")
            formatted_posts.append(f"## {title}\n\n{content}")

        return "\n\n---\n\n".join(formatted_posts)
