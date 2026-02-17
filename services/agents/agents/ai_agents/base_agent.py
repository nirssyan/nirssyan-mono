"""Base class for AI agents with JSON output handling."""

from __future__ import annotations

import asyncio
import json
import re
import time
from typing import Any, Generic, TypeVar

from langchain_core.output_parsers import PydanticOutputParser
from langchain_core.prompts import ChatPromptTemplate
import httpx
from langchain_openai import ChatOpenAI
from loguru import logger
from pydantic import BaseModel, SecretStr, ValidationError
from shared.utils.llm_cost_tracker import track_llm_cost_async
from shared.utils.llm_pricing import calculate_cost

from ..config import settings
from ..metrics import increment_llm_cost, increment_llm_requests, increment_llm_tokens
from ..utils.db import get_db_engine
from .llm_logging import log_llm_request

T = TypeVar("T", bound=BaseModel)


class BaseJSONAgent(Generic[T]):
    """Base class for AI agents that expect JSON output from LLM."""

    def __init__(
        self,
        response_model: type[T],
        system_prompt: str,
        human_prompt_template: str,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
        temperature: float = 0.7,
        tools: list | None = None,
    ):
        """Initialize the base AI agent.

        Args:
            response_model: Pydantic model for expected response structure
            system_prompt: System prompt for the AI
            human_prompt_template: Template for human messages (can have {variables})
            api_key: AI API key. If None, will use config settings.
            base_url: AI base URL. If None, will use config settings.
            model: Model to use for generation. If None, defaults to configured ai_model.
            temperature: Temperature for AI responses
            tools: Optional list of LangChain tools for function calling.
                If provided, the LLM will be bound with these tools for tool calling.
        """
        self.response_model = response_model
        self.api_key = api_key or settings.ai_api_key
        self.base_url = base_url or settings.ai_base_url
        self.model = model or settings.ai_model
        self.temperature = temperature

        if not self.api_key:
            raise ValueError("AI API key must be provided in config or as parameter")

        if not self.base_url:
            raise ValueError("AI base URL must be provided in config or as parameter")

        llm_kwargs: dict[str, Any] = {
            "api_key": SecretStr(self.api_key),
            "base_url": self.base_url,
            "model": self.model,
            "temperature": self.temperature,
            "timeout": settings.llm_request_timeout,
        }

        if settings.proxy_url:
            proxy = settings.proxy_url
            if settings.proxy_username and settings.proxy_password:
                scheme, rest = proxy.split("://", 1)
                proxy = f"{scheme}://{settings.proxy_username}:{settings.proxy_password}@{rest}"
            llm_kwargs["http_async_client"] = httpx.AsyncClient(proxy=proxy)
            llm_kwargs["http_client"] = httpx.Client(proxy=proxy)

        self.llm = ChatOpenAI(**llm_kwargs)

        # Bind tools to LLM if provided
        llm_with_tools = self.llm.bind_tools(tools) if tools else self.llm

        # Set up Pydantic output parser (for format instructions only)
        self.output_parser = PydanticOutputParser(pydantic_object=response_model)

        # Create prompt template with format instructions
        self.prompt = ChatPromptTemplate.from_messages(
            [
                (
                    "system",
                    system_prompt
                    + "\n\n{format_instructions}\n\n"
                    + "IMPORTANT: Return ONLY the JSON object. "
                    + "Do not repeat the schema, field descriptions or examples provided in the format instructions. "
                    + "Do not include any text before or after the JSON object.",
                ),
                ("human", human_prompt_template),
            ],
        ).partial(format_instructions=self.output_parser.get_format_instructions())

        # Create the chain WITHOUT output_parser - we'll parse manually for better error handling
        self.chain = self.prompt | llm_with_tools

    def _decode_unicode_escapes(self, text: str) -> str:
        """Decode unicode escape sequences for readable logging.

        Args:
            text: Text that may contain \\uXXXX sequences

        Returns:
            Text with decoded unicode characters
        """
        try:
            # Try to decode unicode escape sequences
            # encode as latin1 to preserve \\uXXXX, then decode as unicode-escape
            return text.encode("latin1").decode("unicode-escape")
        except (UnicodeDecodeError, UnicodeEncodeError, AttributeError):
            # If decoding fails, try json formatting
            try:
                # Try to parse and re-format with ensure_ascii=False
                parsed = json.loads(text)
                return json.dumps(parsed, ensure_ascii=False, indent=2)
            except (json.JSONDecodeError, TypeError):
                # If all else fails, return original
                return text

    def _fix_malformed_unicode(self, text: str) -> str:
        """Fix malformed unicode escape sequences like \\uuXXXX -> \\uXXXX."""
        return re.sub(r"\\u(u+)([0-9a-fA-F]{4})", r"\\u\2", text)

    def _preprocess_llm_output(self, text: str) -> str:
        """Remove markdown code blocks and clean LLM output.

        Handles cases where LLM wraps JSON in:
        - ```json ... ```
        - ``` ... ```
        - ```python ... ```

        Args:
            text: Raw LLM output potentially with markdown

        Returns:
            Cleaned text without markdown wrappers
        """
        text = self._fix_malformed_unicode(text)

        # Remove markdown code blocks: ```json\n{...}\n``` or ```\n{...}\n```
        # The (?:json|python)? makes the language identifier optional
        text = re.sub(
            r"```(?:json|python)?\s*\n?(.*?)\n?```", r"\1", text, flags=re.DOTALL
        )

        return text.strip()

    def _fix_unescaped_quotes(self, text: str) -> str:
        """Attempt to fix unescaped quotes inside JSON string values.

        This handles cases where LLM generates text like:
        {"key": "value with "unescaped" quotes"}

        And converts to:
        {"key": "value with \"escaped\" quotes"}

        Args:
            text: Raw text potentially containing JSON with unescaped quotes

        Returns:
            Text with attempted fixes for unescaped quotes
        """
        result = []
        i = 0
        while i < len(text):
            char = text[i]

            # Check if we're at the start of a JSON string value (after ': "')
            if i >= 2 and text[i - 2 : i] == ": " and char == '"':
                # We're starting a string value, collect it
                result.append(char)
                i += 1

                # Now collect the value until we find the closing quote
                # We need to track escaped characters
                escape_next = False
                while i < len(text):  # pyrefly: ignore[bad-assignment]
                    char = text[i]

                    if escape_next:
                        # This character is already escaped
                        result.append(char)
                        escape_next = False
                        i += 1
                        continue

                    if char == "\\":
                        # Next character will be escaped
                        result.append(char)
                        escape_next = True
                        i += 1
                        continue

                    if char == '"':
                        # Found a quote - is it the end of the string value?
                        # Check what comes after
                        if i + 1 < len(text):
                            next_char = text[i + 1]
                            # If next char is comma, closing brace/bracket, or whitespace followed by these,
                            # this is the closing quote
                            if next_char in ",}]":
                                result.append(char)
                                i += 1
                                break
                            elif next_char in " \n\t":
                                # Look ahead to see if whitespace is followed by comma/brace/bracket
                                j = i + 1
                                while j < len(text) and text[j] in " \n\t":
                                    j += 1
                                if j < len(text) and text[j] in ",}]":
                                    # This is the closing quote
                                    result.append(char)
                                    i += 1
                                    break

                        # This is an unescaped quote inside the value - escape it
                        result.append("\\")
                        result.append(char)
                        i += 1
                    else:
                        result.append(char)
                        i += 1
            else:
                result.append(char)
                i += 1

        return "".join(result)

    def _try_fast_parse(
        self, text: str, expected_fields: list | None = None
    ) -> dict | None:
        """Tier 1: Fast parsing using current logic (json.loads + find_json_objects).

        This handles 90% of cases quickly without external libraries.

        Args:
            text: Preprocessed text potentially containing JSON
            expected_fields: List of field names that should be in the JSON

        Returns:
            Extracted JSON dict or None if no valid JSON found
        """
        # Try to parse entire text as JSON (fastest path)
        try:
            parsed = json.loads(text.strip())
            if isinstance(parsed, dict):
                if expected_fields and not any(
                    field in parsed for field in expected_fields
                ):
                    logger.debug(
                        f"Fast parse: Found dict but missing expected fields. "
                        f"Expected: {expected_fields}, Found keys: {list(parsed.keys())}"
                    )
                    return None
                return parsed
        except json.JSONDecodeError as e:
            logger.debug(
                f"Fast parse: Failed to parse entire text as JSON. "
                f"Error: {e.msg} at line {e.lineno}, column {e.colno}"
            )

        # Find JSON objects by balanced braces
        def find_json_objects(s: str) -> list[str]:
            """Find all potential JSON objects in string by matching balanced braces."""
            results = []
            start_idx = 0

            while True:
                start = s.find("{", start_idx)
                if start == -1:
                    break

                depth = 0
                in_string = False
                escape = False

                for i in range(start, len(s)):
                    char = s[i]

                    if escape:
                        escape = False
                        continue
                    if char == "\\":
                        escape = True
                        continue

                    if char == '"':
                        in_string = not in_string
                        continue

                    if not in_string:
                        if char == "{":
                            depth += 1
                        elif char == "}":
                            depth -= 1
                            if depth == 0:
                                candidate = s[start : i + 1]
                                results.append(candidate)
                                start_idx = i + 1
                                break

                if depth != 0:
                    start_idx = start + 1

            return results

        candidates = find_json_objects(text)

        # Try to parse each candidate
        for idx, candidate in enumerate(candidates):
            try:
                parsed = json.loads(candidate)
                if isinstance(parsed, dict):
                    if expected_fields and not any(
                        field in parsed for field in expected_fields
                    ):
                        logger.debug(
                            f"Fast parse: Candidate {idx + 1}/{len(candidates)} missing expected fields. "
                            f"Expected: {expected_fields}, Found keys: {list(parsed.keys())}"
                        )
                        continue
                    return parsed
            except json.JSONDecodeError as e:
                # Try fix unescaped quotes
                try:
                    fixed_candidate = self._fix_unescaped_quotes(candidate)
                    parsed = json.loads(fixed_candidate)
                    if isinstance(parsed, dict):
                        if expected_fields and not any(
                            field in parsed for field in expected_fields
                        ):
                            logger.debug(
                                f"Fast parse: Fixed candidate {idx + 1}/{len(candidates)} missing expected fields. "
                                f"Expected: {expected_fields}, Found keys: {list(parsed.keys())}"
                            )
                            continue
                        logger.info(
                            "Successfully parsed JSON after fixing unescaped quotes (fast path)"
                        )
                        return parsed
                except json.JSONDecodeError as e2:
                    logger.debug(
                        f"Fast parse: Candidate {idx + 1}/{len(candidates)} failed even after quote fix. "
                        f"Original error: {e.msg}, Fixed error: {e2.msg}"
                    )
                    continue

        logger.debug(
            f"Fast parse: Exhausted all {len(candidates)} candidates without finding valid JSON"
        )
        return None

    def _try_repair_parse(
        self, text: str, expected_fields: list | None = None
    ) -> dict | None:
        """Tier 2: Repair parsing using json_repair library.

        This handles truncated JSON, missing quotes, and other LLM mistakes.
        Used as fallback when fast parsing fails (9% of cases).

        Args:
            text: Preprocessed text potentially containing malformed JSON
            expected_fields: List of field names that should be in the JSON

        Returns:
            Repaired and parsed JSON dict or None if repair failed
        """
        try:
            from json_repair import repair_json

            logger.debug("Repair parse: Attempting json_repair on malformed JSON")

            # Repair with кириллица support, return Python object directly
            repaired = repair_json(text, ensure_ascii=False, return_objects=True)

            if isinstance(repaired, dict):
                # Validate expected fields
                if expected_fields and not any(f in repaired for f in expected_fields):
                    logger.debug(
                        f"Repair parse: Repaired dict missing expected fields. "
                        f"Expected: {expected_fields}, Found keys: {list(repaired.keys())}"
                    )
                    return None

                logger.info("Successfully parsed JSON using json_repair (repair path)")
                return repaired

            if isinstance(repaired, list):
                logger.debug(
                    f"Repair parse: json_repair returned list with {len(repaired)} items"
                )
                # Look for a dict that matches expected fields
                for idx, item in enumerate(repaired):
                    if isinstance(item, dict):
                        if not expected_fields or any(
                            f in item for f in expected_fields
                        ):
                            logger.info(
                                "Successfully found matching dict in json_repair list"
                            )
                            return item
                        else:
                            logger.debug(
                                f"Repair parse: List item {idx + 1}/{len(repaired)} missing expected fields. "
                                f"Expected: {expected_fields}, Found keys: {list(item.keys())}"
                            )
                logger.debug("Repair parse: No dict in list matched expected fields")

        except Exception as e:
            logger.debug(
                f"Repair parse: json_repair failed with exception: {type(e).__name__}: {e}"
            )
            return None

        logger.debug(
            "Repair parse: json_repair succeeded but result didn't match expected format"
        )
        return None

    def _extract_json_from_text(
        self, text: str, expected_fields: list | None = None
    ) -> dict | None:
        """Extract JSON from mixed text response using multi-tier parsing.

        Strategy:
        - Tier 1 (Fast Path): Preprocessing + json.loads + balanced braces (90% cases)
        - Tier 2 (Repair Path): json_repair for truncated/malformed JSON (9% cases)
        - Tier 3 (Fallback): Return None (1% cases)

        Args:
            text: Raw text that might contain JSON
            expected_fields: List of field names that should be in the JSON

        Returns:
            Extracted JSON dict or None if no valid JSON found
        """
        # Preprocessing: Remove markdown code blocks (fast, ~0.01ms)
        text = self._preprocess_llm_output(text)

        # TIER 1: Fast path - current logic (90% of cases, ~0.1-0.5ms)
        result = self._try_fast_parse(text, expected_fields)
        if result:
            return result

        # TIER 1.5: Brace wrapping - handle LLM returning fields without outer braces
        if expected_fields:
            has_field_keys = any(
                f'"{f}"' in text or f"'{f}'" in text for f in expected_fields
            )
            if has_field_keys:
                wrapped = "{" + text.strip().rstrip(",") + "}"
                try:
                    parsed = json.loads(wrapped)
                    if isinstance(parsed, dict) and any(
                        f in parsed for f in expected_fields
                    ):
                        logger.info(
                            "Successfully parsed JSON by wrapping in braces (brace-wrap path)"
                        )
                        return parsed
                except json.JSONDecodeError:
                    pass

        # TIER 2: Repair path - json_repair library (9% of cases, ~1-5ms)
        result = self._try_repair_parse(text, expected_fields)
        if result:
            return result

        # TIER 3: Content wrapper - if only "content" field expected, wrap raw text
        if expected_fields == ["content"] and text.strip():
            logger.debug(
                "JSON extraction failed, wrapping raw text in content field "
                f"(text length: {len(text)})"
            )
            return {"content": text.strip()}

        # TIER 4: Failed to parse
        return None

    def _parse_response(self, raw_content: str, method_name: str) -> T:
        """Parse LLM response and create validated Pydantic model.

        Args:
            raw_content: Raw text response from LLM
            method_name: Name of the calling method for logging

        Returns:
            Validated response model instance

        Raises:
            ValueError: If JSON extraction or validation fails
        """
        # Get expected fields from response model
        expected_fields = list(self.response_model.model_fields.keys())

        # Try to extract JSON from raw content
        extracted_json = self._extract_json_from_text(raw_content, expected_fields)

        if not extracted_json:
            # Log the raw content for debugging with full context
            content_length = len(raw_content)
            log_preview_length = 2000
            readable_content = self._decode_unicode_escapes(
                raw_content[:log_preview_length]
            )
            truncation_indicator = "..." if content_length > log_preview_length else ""
            logger.error(
                f"Failed to extract JSON from LLM response in {method_name}. "
                f"Expected fields: {expected_fields}, "
                f"Raw content length: {content_length} chars. "
                f"Raw content preview: {readable_content}{truncation_indicator}"
            )
            raise ValueError(
                f"Could not find valid JSON in LLM response. Expected fields: {expected_fields}"
            )

        # Try to create and validate Pydantic model
        try:
            result = self.response_model(**extracted_json)
            logger.debug(f"Successfully parsed and validated response in {method_name}")
            return result  # type: ignore[no-any-return]
        except ValidationError as e:
            logger.error(f"Pydantic validation failed in {method_name}: {e}")
            logger.error(f"Extracted JSON: {extracted_json}")
            raise ValueError(f"Response validation failed: {e}") from e

    async def _invoke_chain_async(
        self, input_data: dict[str, Any], method_name: str, user_id: str | None = None
    ) -> T:
        """Invoke the chain asynchronously with error handling.

        Args:
            input_data: Input data for the chain
            method_name: Name of the calling method for logging
            user_id: Optional user ID (unused, kept for API compatibility)

        Returns:
            Validated response model instance

        Raises:
            ValueError: If generation or parsing fails
        """
        max_retries = 3
        last_exception = None

        for attempt in range(max_retries):
            try:
                # Invoke chain (returns AIMessage since we removed output_parser)
                # OpenLLMetry automatically instruments LLM calls for observability
                # Wrap with timeout to prevent hanging on slow LLM responses
                start_time = time.perf_counter()
                try:
                    ai_message = await asyncio.wait_for(
                        self.chain.ainvoke(input_data),
                        timeout=settings.llm_request_timeout,
                    )
                except asyncio.TimeoutError:
                    logger.warning(
                        f"LLM request timed out after {settings.llm_request_timeout}s "
                        f"in {method_name} (attempt {attempt + 1}/{max_retries})"
                    )
                    if attempt < max_retries - 1:
                        await asyncio.sleep(
                            2**attempt
                        )  # Exponential backoff: 1s, 2s, 4s
                        continue
                    raise ValueError(
                        f"LLM request timed out after {settings.llm_request_timeout}s"
                    ) from None

                # Calculate duration
                duration_ms = (time.perf_counter() - start_time) * 1000

                # Track LLM request metric with agent class name
                increment_llm_requests(self.__class__.__name__)

                # Initialize for logging
                prompt_tokens = 0
                completion_tokens = 0
                cost_usd = 0.0

                # Extract token usage and calculate cost if available
                if (
                    hasattr(ai_message, "usage_metadata")
                    and ai_message.usage_metadata
                    and isinstance(ai_message.usage_metadata, dict)
                ):
                    usage = ai_message.usage_metadata
                    prompt_tokens = usage.get("input_tokens", 0)
                    completion_tokens = usage.get("output_tokens", 0)

                    if prompt_tokens > 0 or completion_tokens > 0:
                        # Calculate cost
                        cost_usd = calculate_cost(
                            self.model, prompt_tokens, completion_tokens
                        )

                        # Track Prometheus metrics for tokens and cost
                        increment_llm_tokens(
                            agent=self.__class__.__name__,
                            model=self.model,
                            prompt_tokens=prompt_tokens,
                            completion_tokens=completion_tokens,
                        )
                        increment_llm_cost(
                            agent=self.__class__.__name__,
                            model=self.model,
                            cost_usd=cost_usd,
                        )

                        # Track in database if user_id provided and engine available
                        if user_id:
                            engine = get_db_engine()
                            if engine:
                                await track_llm_cost_async(
                                    engine=engine,
                                    user_id=user_id,
                                    agent=self.__class__.__name__,
                                    model=self.model,
                                    prompt_tokens=prompt_tokens,
                                    completion_tokens=completion_tokens,
                                    cost_usd=cost_usd,
                                )

                # Extract raw content from AIMessage
                raw_content = (
                    ai_message.content
                    if hasattr(ai_message, "content")
                    else str(ai_message)
                )

                # Ensure raw_content is a string (could be list for tool calls)
                if isinstance(raw_content, list):
                    raw_content = str(raw_content)

                # Log LLM request in unified format
                log_llm_request(
                    agent=self.__class__.__name__,
                    duration_ms=duration_ms,
                    cost_usd=cost_usd,
                    prompt_tokens=prompt_tokens,
                    completion_tokens=completion_tokens,
                    input_data=input_data,
                    output=raw_content,
                )

                # Check for empty response and retry if needed
                if not raw_content or not raw_content.strip():
                    if attempt < max_retries - 1:
                        logger.warning(
                            f"Empty LLM response in {method_name}, "
                            f"retrying (attempt {attempt + 1}/{max_retries})"
                        )
                        await asyncio.sleep(
                            2**attempt
                        )  # Exponential backoff: 1s, 2s, 4s
                        continue
                    else:
                        logger.error(
                            f"Empty LLM response after {max_retries} attempts in {method_name}"
                        )
                        raise ValueError(
                            "LLM returned empty response after all retry attempts"
                        )

                # Parse JSON manually with robust extraction
                result = self._parse_response(raw_content, method_name)
                return result

            except ValueError as e:
                # Re-raise ValueError immediately (parsing errors, empty responses)
                last_exception = e
                if attempt < max_retries - 1 and "empty response" in str(e).lower():
                    await asyncio.sleep(2**attempt)  # Exponential backoff: 1s, 2s, 4s
                    continue
                raise
            except Exception as e:
                last_exception = e
                if attempt < max_retries - 1:
                    logger.warning(
                        f"Error in {method_name} (attempt {attempt + 1}/{max_retries}): {e}"
                    )
                    await asyncio.sleep(2**attempt)  # Exponential backoff: 1s, 2s, 4s
                    continue
                logger.error(
                    f"Error in {method_name} after {max_retries} attempts: {e}"
                )
                raise ValueError(f"Error in AI agent execution: {e}") from e

        # Should never reach here, but handle edge case
        if last_exception:
            raise ValueError(
                f"Error in AI agent execution: {last_exception}"
            ) from last_exception
        raise ValueError("Failed to invoke chain after all retry attempts")

    def _invoke_chain_sync(
        self, input_data: dict[str, Any], method_name: str, user_id: str | None = None
    ) -> T:
        """Invoke the chain synchronously with error handling.

        Args:
            input_data: Input data for the chain
            method_name: Name of the calling method for logging
            user_id: Optional user ID (unused, kept for API compatibility)

        Returns:
            Validated response model instance

        Raises:
            ValueError: If generation or parsing fails
        """
        try:
            # Invoke chain (returns AIMessage since we removed output_parser)
            # OpenLLMetry automatically instruments LLM calls for observability
            ai_message = self.chain.invoke(input_data)

            # Extract raw content from AIMessage
            raw_content = (
                ai_message.content
                if hasattr(ai_message, "content")
                else str(ai_message)
            )

            # Ensure raw_content is a string (could be list for tool calls)
            if isinstance(raw_content, list):
                raw_content = str(raw_content)

            # Parse JSON manually with robust extraction
            result = self._parse_response(raw_content, method_name)
            return result

        except Exception as e:
            logger.error(f"Error in {method_name}: {e}")
            raise ValueError(f"Error in AI agent execution: {e}") from e
