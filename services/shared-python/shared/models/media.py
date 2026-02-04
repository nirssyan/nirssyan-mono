"""Media object models for structured media metadata."""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class BaseMediaObject(BaseModel):
    """Base class for all media objects."""

    type: str = Field(examples=["photo", "video", "animation", "document"])
    url: str = Field(
        ...,
        description="URL to media file via /media endpoint",
        examples=["https://api.makefeed.app/media/abc123"],
    )
    mime_type: str = Field(
        ...,
        description="MIME type of the media file",
        examples=["image/jpeg", "video/mp4", "application/pdf"],
    )


class PhotoMediaObject(BaseMediaObject):
    """Photo media object (images from Telegram)."""

    type: Literal["photo"] = "photo"
    mime_type: str = Field(
        ...,
        description="MIME type of the image (e.g., image/jpeg, image/png, image/webp)",
        examples=["image/jpeg", "image/png", "image/webp"],
    )
    width: int | None = Field(
        None, description="Photo width in pixels", examples=[1920, 1280, None]
    )
    height: int | None = Field(
        None, description="Photo height in pixels", examples=[1080, 720, None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "type": "photo",
                    "url": "https://api.makefeed.app/media/abc123",
                    "mime_type": "image/jpeg",
                    "width": 1920,
                    "height": 1080,
                }
            ]
        }
    )


class VideoMediaObject(BaseMediaObject):
    """Video media object with thumbnail preview."""

    type: Literal["video"] = "video"
    preview_url: str = Field(
        ...,
        description="URL to video thumbnail via /media endpoint",
        examples=["https://api.makefeed.app/media/thumb123"],
    )
    width: int | None = Field(
        None, description="Video width in pixels", examples=[1920, 1280, None]
    )
    height: int | None = Field(
        None, description="Video height in pixels", examples=[1080, 720, None]
    )
    duration: float | None = Field(
        None,
        description="Video duration in seconds (can have fractional part)",
        examples=[125.5, 60.0, None],
    )
    file_name: str | None = Field(
        None, description="Original file name", examples=["presentation.mp4", None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "type": "video",
                    "url": "https://api.makefeed.app/media/video123",
                    "mime_type": "video/mp4",
                    "preview_url": "https://api.makefeed.app/media/thumb123",
                    "width": 1280,
                    "height": 720,
                    "duration": 125.5,
                    "file_name": "presentation.mp4",
                }
            ]
        }
    )


class AnimationMediaObject(BaseMediaObject):
    """Animation media object (GIFs, animated stickers)."""

    type: Literal["animation"] = "animation"
    preview_url: str | None = Field(
        None,
        description="URL to animation thumbnail via /media endpoint (if available)",
        examples=["https://api.makefeed.app/media/animthumb456", None],
    )
    width: int | None = Field(
        None, description="Animation width in pixels", examples=[480, 320, None]
    )
    height: int | None = Field(
        None, description="Animation height in pixels", examples=[360, 240, None]
    )
    file_name: str | None = Field(
        None, description="Original file name", examples=["reaction.gif", None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "type": "animation",
                    "url": "https://api.makefeed.app/media/anim456",
                    "mime_type": "image/gif",
                    "preview_url": "https://api.makefeed.app/media/animthumb456",
                    "width": 480,
                    "height": 360,
                    "file_name": "reaction.gif",
                }
            ]
        }
    )


class DocumentMediaObject(BaseMediaObject):
    """Document media object (files, PDFs, etc)."""

    type: Literal["document"] = "document"
    file_name: str | None = Field(
        None,
        description="Original file name",
        examples=["research_paper.pdf", "report.docx", None],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "type": "document",
                    "url": "https://api.makefeed.app/media/doc789",
                    "mime_type": "application/pdf",
                    "file_name": "research_paper.pdf",
                }
            ]
        }
    )


# Union type for all media objects
MediaObject = (
    PhotoMediaObject | VideoMediaObject | AnimationMediaObject | DocumentMediaObject
)
