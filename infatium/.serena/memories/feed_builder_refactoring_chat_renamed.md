# Feed Builder Refactoring Summary

## Overview
The "Chat" terminology was renamed to "Feed Builder" throughout the codebase because the second tab is now used for creating feeds (single posts and digests) rather than traditional chat functionality.

## File Renames
| Old Name | New Name |
|----------|----------|
| `lib/models/chat_models.dart` | `lib/models/feed_builder_models.dart` |
| `lib/services/chat_service.dart` | `lib/services/feed_builder_service.dart` |
| `lib/services/chat_cache_service.dart` | `lib/services/feed_builder_cache_service.dart` |
| `lib/services/chat_state_service.dart` | `lib/services/feed_builder_state_service.dart` |
| `lib/pages/chat_page.dart` | `lib/pages/feed_builder_page.dart` |
| `lib/pages/chat_tab_page.dart` | `lib/pages/feed_builder_tab_page.dart` |
| `lib/pages/chat_list_page.dart` | `lib/pages/feed_builder_list_page.dart` |

## Class Renames
| Old Name | New Name |
|----------|----------|
| `Chat` | `FeedBuilderSession` |
| `ChatMessage` | `FeedBuilderMessage` |
| `CreateChatResponse` | `CreateSessionResponse` |
| `ChatService` | `FeedBuilderService` |
| `ChatCacheService` | `FeedBuilderCacheService` |
| `ChatStateService` | `FeedBuilderStateService` |
| `ChatPage` | `FeedBuilderPage` |
| `ChatTabPage` | `FeedBuilderTabPage` |
| `ChatListPage` | `FeedBuilderListPage` |

## Backend API Compatibility
JSON keys were intentionally kept unchanged to maintain backend API compatibility:
- `chat_id` - kept in JSON serialization
- `/chats` endpoint - kept (backend not changed)

Internal Dart variable/property names use `sessionId` while JSON uses `chat_id`.

## Localization Changes
- Tab label: "Чаты"/"Chats" → "Создать"/"Create"
- All chat-related strings updated to use "session" terminology
