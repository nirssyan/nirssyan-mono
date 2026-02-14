# MakeFeed API OpenAPI Endpoints

Source: https://dev.service.infatium.ru/schema/openapi.json

## Feed Creation

### POST /feeds/create (CreateFeedFull)
Creates a complete feed with sources, filters, and processing rules.

**Request Body** (`CreateFeedFullRequest`):
```json
{
  "name": "string (optional - backend auto-generates if null)",
  "sources": [{"url": "string", "type": "RSS|TELEGRAM|SEARCH"}] (required, min 1),
  "feed_type": "SINGLE_POST | DIGEST (required)",
  "description": "string (optional)",
  "tags": ["string array (optional)"],
  "raw_prompt": "string (optional)",
  "views_raw": ["string array (optional)"],
  "filters_raw": ["string array (optional)"],
  "digest_interval_hours": "integer 1-48 (optional, only for DIGEST)"
}
```

**Response** (`CreateFeedFullResponse`):
```json
{
  "success": "boolean",
  "feed_id": "UUID",
  "prompt_id": "UUID",
  "message": "string",
  "is_creating_finished": "boolean"
}
```

### POST /chats/create_feed (CreateFeed) - LEGACY
Creates feed from chat conversation.

**Request Body** (`CreateFeedRequest`):
```json
{
  "chat_id": "UUID (required)"
}
```

**Response** (`CreateFeedResponse`):
```json
{
  "success": "boolean",
  "feed_id": "UUID",
  "message": "string",
  "is_creating_finished": "boolean"
}
```

## Title Generation

### POST /feeds/generate_title (GenerateTitle) - NEW
Generates feed title from source configuration (no chat/feed required).

**Request Body** (`GenerateTitleRequest`):
```json
{
  "sources": ["string array (required)"],
  "feed_type": "SINGLE_POST | DIGEST (required)",
  "raw_prompt": "string (optional)",
  "views_raw": ["string array (optional)"],
  "filters_raw": ["string array (optional)"],
  "digest_interval_hours": "integer (optional)"
}
```

**Response** (`GenerateTitleResponse`):
```json
{
  "title": "string (max 30 characters)"
}
```

### GET /modal/generate_title/{feed_id} (GenerateFeedTitle) - LEGACY
Generates title for existing feed.

**Path Parameters**:
- `feed_id`: UUID of existing feed

**Response** (`GenerateTitleResponse`):
```json
{
  "title": "string"
}
```

## Source Validation

### POST /sources/validate (ValidateSource)
Validates RSS URL or Telegram channel.

**Request Body** (`SourceValidationRequest`):
```json
{
  "source": "string (required)"
}
```

**Response** (`SourceValidationResponse`):
```json
{
  "is_valid": "boolean",
  "source_type": "TELEGRAM | RSS | WEBSITE | null",
  "short_name": "string | null"
}
```

**Status Codes**:
- 200: Success (check is_valid field)
- 422: Invalid source format

## Chat Endpoints

### GET /chats (GetChats)
Lists all user chats with messages.

### POST /chats (CreateChat)
Creates new chat session.

### POST /chats/chat_message (ProcessChatMessage)
Sends message in chat and receives AI response.

### DELETE /chats/{chat_id} (DeleteChat)
Removes chat session.

### PATCH /chats/{chat_id}/feed_preview (UpdateFeedPreview)
Updates feed configuration preview from chat.

## Best Practice Recommendations

1. **Feed Creation**: Use `POST /feeds/create` directly instead of the chat flow
2. **Title Generation**: Use `POST /feeds/generate_title` without creating a chat first
3. **Source Validation**: Validate each source with `POST /sources/validate` before adding to form
