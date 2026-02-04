"""OpenRouter API client for fetching LLM models."""

from typing import Any

import httpx
from loguru import logger

OPENROUTER_MODELS_URL = "https://openrouter.ai/api/v1/models"


class OpenRouterClientError(Exception):
    """Error from OpenRouter API client."""

    pass


class OpenRouterClient:
    """Client for fetching models from OpenRouter API.

    OpenRouter API returns all available models with their pricing
    and capabilities. The API is public and doesn't require authentication.

    Example:
        client = OpenRouterClient()
        models = await client.fetch_models()
    """

    def __init__(self, timeout: float = 60.0) -> None:
        """Initialize the OpenRouter client.

        Args:
            timeout: Request timeout in seconds
        """
        self._timeout = timeout

    async def fetch_models(self) -> list[dict[str, Any]]:
        """Fetch all models from OpenRouter API.

        Returns list of models with:
        - id: "google/gemini-3-flash-preview"
        - name: "Google: Gemini 3 Flash Preview"
        - created: 1765987078 (Unix timestamp, optional)
        - pricing: {prompt, completion, image, audio, ...}
        - context_length: 1048576
        - architecture: {input_modalities, output_modalities}

        Returns:
            List of model dictionaries

        Raises:
            OpenRouterClientError: If API request fails
        """
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.get(OPENROUTER_MODELS_URL)
                response.raise_for_status()
                data = response.json()
                models = data.get("data", [])
                logger.info(f"Fetched {len(models)} models from OpenRouter API")
                return models
        except httpx.TimeoutException as e:
            raise OpenRouterClientError(f"OpenRouter API timeout: {e}") from e
        except httpx.HTTPStatusError as e:
            raise OpenRouterClientError(
                f"OpenRouter API HTTP error {e.response.status_code}: {e}"
            ) from e
        except httpx.RequestError as e:
            raise OpenRouterClientError(f"OpenRouter API request error: {e}") from e
        except Exception as e:
            raise OpenRouterClientError(f"OpenRouter API error: {e}") from e

    def parse_model_data(self, raw_model: dict[str, Any]) -> dict[str, Any]:
        """Parse raw model data from OpenRouter API into database format.

        Args:
            raw_model: Raw model dict from API

        Returns:
            Parsed model dict ready for database insertion
        """
        model_id = raw_model.get("id", "")
        provider = model_id.split("/")[0] if "/" in model_id else "unknown"

        pricing = raw_model.get("pricing", {})
        architecture = raw_model.get("architecture", {})

        return {
            "model_id": model_id,
            "provider": provider,
            "name": raw_model.get("name", model_id),
            "model_created_at": raw_model.get("created"),
            "context_length": raw_model.get("context_length"),
            "input_modalities": architecture.get("input_modalities", ["text"]),
            "output_modalities": architecture.get("output_modalities", ["text"]),
            "price_prompt": self._parse_price(pricing.get("prompt", "0")),
            "price_completion": self._parse_price(pricing.get("completion", "0")),
            "price_image": self._parse_price(pricing.get("image", "0")),
            "price_audio": self._parse_price(pricing.get("audio", "0")),
            "is_active": True,
        }

    def _parse_price(self, price_value: str | float | int | None) -> str:
        """Parse price value to string for Numeric column.

        OpenRouter returns prices as strings like "0.0000005" per token.

        Args:
            price_value: Price value from API (string, float, int, or None)

        Returns:
            Price as string for Decimal/Numeric column
        """
        if price_value is None:
            return "0"
        if isinstance(price_value, str):
            try:
                return str(float(price_value))
            except ValueError:
                return "0"
        return str(price_value)
