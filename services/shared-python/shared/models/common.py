"""Common models shared across the application."""

from pydantic import BaseModel, Field


class LocalizedName(BaseModel):
    """Localized name supporting multiple languages."""

    en: str = Field(description="English name")
    ru: str = Field(description="Russian name")


def get_localized_name_str(name: str | dict | None, lang: str = "en") -> str:
    """Extract string name from LocalizedName dict or return string as-is.

    Args:
        name: Either a string, LocalizedName dict {"en": ..., "ru": ...}, or None
        lang: Preferred language ("en" or "ru"), fallback to other if empty

    Returns:
        String name or empty string
    """
    if name is None:
        return ""
    if isinstance(name, str):
        return name
    if isinstance(name, dict):
        value = name.get(lang)
        if isinstance(value, str) and value:
            return value
        fallback_lang = "ru" if lang == "en" else "en"
        fallback_value = name.get(fallback_lang)
        if isinstance(fallback_value, str):
            return fallback_value
        return ""
    return ""
