# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Makefeed** is a cross-platform Flutter application (iOS, Android, Web, macOS, Windows, Linux) for personalized news feeds and AI-powered chat. The app uses a custom authentication service and Yandex AppMetrica for analytics.

**Key Languages**: Dart 3.8.1+, Flutter 3.24+, Kotlin (Android), Swift (iOS)

## Development Commands

### Quick Start (Recommended)

**One-click development:**
```bash
./scripts/run-dev.sh              # Run on default device
./scripts/run-dev.sh -d chrome    # Run on Chrome
./scripts/run-dev.sh -d macos     # Run on macOS
```

**One-click builds:**
```bash
./scripts/build-ios-dev.sh        # iOS development build (Bundle ID: com.nirssyan.makefeed.dev)
./scripts/build-ios-prod.sh       # iOS production build (Bundle ID: com.nirssyan.makefeed)
./scripts/build-android-dev.sh    # Android development build
./scripts/build-android-prod.sh   # Android production build
```

**Parallel iOS Installation** (Dev + Prod side-by-side):
The iOS build scripts create apps with different Bundle IDs, enabling simultaneous installation:
- **Dev** (`порнахаб`): `com.nirssyan.makefeed.dev` - for TestFlight
- **Prod** (`infatium`): `com.nirssyan.makefeed` - for App Store

**First time iOS setup**: See [`XCODE_SETUP_GUIDE.md`](./XCODE_SETUP_GUIDE.md) for Xcode configuration (required once).

**First time setup:**
```bash
./scripts/setup.sh                # Create config files with dev keys
# Config files are ready to use immediately!
```

**VS Code users:**
- Press `Cmd+Shift+B` (macOS) or `Ctrl+Shift+B` (Windows/Linux)
- Select "Run Dev" or "Run Prod"

### Configuration System

The app uses `config/*.local.json` files for environment configuration. See `config/README.md` for details.

**Active configuration variables:**

| Variable | Type | Default (Dev) | Description |
|----------|------|---------------|-------------|
| `API_KEY` | **Secret** | (in examples) | Backend API key |
| `APPMETRICA_API_KEY` | **Secret** | (in examples) | AppMetrica analytics key |
| `GLITCHTIP_DSN` | **Secret** | (in examples) | GlitchTip error tracking DSN |
| `API_BASE_URL` | Public | `https://dev.api.infatium.ru` | Backend URL |
| `CUSTOM_AUTH_BASE_URL` | Public | `https://dev.api.infatium.ru/auth` | Auth URL |
| `SHARE_BASE_URL` | Public | `https://dev.infatium.ru` | Base URL for shared news links |
| `SPLASH_TEXT` | Public | `infatium` | Splash screen text |
| `ENABLE_NOTIFICATIONS` | Public | `true` | Push notifications |
| `ENABLE_DEBUG_LOGGING` | Public | `true` (dev), `false` (prod) | Debug logging to `/debug/echo` |

**Note:** Dev API keys are included in `config/*.example` files for convenience. Production keys should be kept secret.

### Manual Run (Old Workflow)

If you prefer the old `--dart-define` workflow:

```bash
# Minimal run command
flutter run \
  --dart-define=API_KEY=your_api_key \
  --dart-define=APPMETRICA_API_KEY=your_appmetrica_key

# With custom config file
flutter run --dart-define-from-file=config/dev.local.json

# Run on specific device
flutter run -d chrome --dart-define-from-file=config/dev.local.json
```

### Building for Release (Manual)

```bash
# iOS App Store
flutter build ipa --release --dart-define-from-file=config/prod.local.json

# Android APK
flutter build apk --release --dart-define-from-file=config/prod.local.json

# Android App Bundle
flutter build appbundle --release --dart-define-from-file=config/prod.local.json
```

### Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

### Code Quality

```bash
# Analyze code for issues
flutter analyze

# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade
```

### Localization

Localization files are auto-generated during `flutter run` or `flutter build`. To manually regenerate:

```bash
flutter gen-l10n
```

Edit ARB files in `lib/l10n/`:
- `app_en.arb` - English strings
- `app_ru.arb` - Russian strings

## Architecture

### High-Level Structure

The app follows a service-oriented architecture with clear separation between UI (pages/widgets), business logic (services), and data (models).

**Main Entry Points**:
- `lib/main.dart` - Application entry point
- `lib/app.dart` - Root widget with theme, locale, auth initialization
- `lib/navigation/main_tab_scaffold.dart` - Main tab navigation (home, chat, feeds manager, profile)

### Authentication & Authorization

#### Authentication System

**Base URL**: `https://dev.api.infatium.ru/auth` (configurable via `CUSTOM_AUTH_BASE_URL`)

The app uses the `AuthService()` singleton for authentication state management.

**Endpoints**:

| Method | Endpoint | Purpose | Request | Response |
|--------|----------|---------|---------|----------|
| POST | `/auth/google` | Google OAuth | `{"id_token": "..."}` | JWT pair + user |
| POST | `/auth/apple` | Apple OAuth | `{"id_token": "..."}` | JWT pair + user |
| POST | `/auth/magic-link` | Send magic link | `{"email": "..."}` | `{"message": "sent"}` |
| POST | `/auth/verify` | Verify magic link | `{"token": "..."}` | JWT pair + user |
| POST | `/auth/refresh` | Refresh token | `{"refresh_token": "..."}` | New JWT pair |
| POST | `/auth/logout` | Logout | `{"refresh_token": "..."}` | Success |

**JWT Response Format**:
```json
{
  "access_token": "eyJ...",
  "refresh_token": "rt_abc123...",
  "expires_in": 900,
  "token_type": "Bearer",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "provider": "google"
  }
}
```

**Key Features**:
- Access token lifetime: 15 minutes
- Token refresh: Every 14 minutes (1 min before expiry)
- Token storage: Manual (SharedPreferences)
- Auto-refresh: Custom implementation
- Deep link handling: Custom implementation
- OAuth flow: POST id_token to endpoint

**⚠️ CRITICAL: Refresh Token Rotation**

The auth-service uses **refresh token rotation** for enhanced security:
- Every refresh returns a **new** refresh token
- Old refresh token becomes **invalid immediately**
- Reusing an old token returns **409 Conflict** → entire session revoked
- Must save new tokens **before** any other operations

**Error Codes**:
- `400` - `missing_token`, `invalid_token`
- `401` - Unauthorized (expired access token)
- `409` - `token_reused` (security alert - possible token theft)

**Configuration** (`lib/config/auth_config.dart`):
- Base URL: `CUSTOM_AUTH_BASE_URL` (default: production endpoint)
- Token refresh: Every 14 minutes (1 min before 15-min expiry)
- Deep link: `makefeed://auth/callback`

**Platform-Specific Authentication** (`lib/pages/auth_page.dart`):
- **Sign in with Apple**: Only shown on iOS/macOS (native platforms)
  - Uses `Platform.isIOS || Platform.isMacOS` check at runtime
  - Android/Web users see only Google sign-in button at full width
  - Avoids showing Apple sign-in on non-Apple platforms where it's not native
- **Google Sign-In**: Available on all platforms

### OAuth Configuration

**Google OAuth** (`lib/services/auth_service.dart`):
- Project: `715376087095` (Google Cloud Console)
- iOS Client ID: `715376087095-b1rsvvumtrilroc1n6285j531rp81trh.apps.googleusercontent.com`
- Android Client ID: `715376087095-bl8qcgde9ck9bb747vrdtiuod8t2k9v4.apps.googleusercontent.com`
- Web Client ID (serverClientId): `715376087095-6hhrt2ha4qbhobv4lilrp4u8tsmho3uo.apps.googleusercontent.com`

**Important**:
- Android requires SHA-1 certificate fingerprints registered in Google Cloud Console
- iOS requires Bundle ID configured in OAuth client
- All OAuth clients must be from the same Google Cloud project

### Magic Link Configuration

**Magic Link Flow**:

Magic link (passwordless email login) allows users to sign in by clicking a link sent to their email.

**How Magic Link Works**:
1. User enters email on auth page and clicks "Continue with email"
2. App calls `AuthService().signInWithMagicLink(email)`
3. Auth service sends email with verification link containing token
4. User clicks link in email → link redirects to `makefeed://auth/callback`
5. App opens via deep link
6. App detects and verifies the token
7. User is automatically logged in

**Deep Link Configuration**:
- **Android**: Intent filter configured in `android/app/src/main/AndroidManifest.xml:33-42`
- **iOS**: URL scheme `makefeed://` configured in `ios/Runner/Info.plist:40-43`
- **Redirect URL**: `makefeed://auth/callback`

### Backend API Integration

The app communicates with **Python backend microservices** (configured via `ApiConfig`) for backend operations.

**Base URL**: Configured via `API_BASE_URL` (default: `https://dev.api.infatium.ru`)

**Authentication Headers** (all requests):
- `X-API-Key: <API_KEY>` from environment variable
- `user-id: <user_id>` from auth service
- `Authorization: Bearer <JWT>` (session token)

#### Feed Builder API (`lib/services/chat_service.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/chats` | All user sessions |
| POST | `/chats` | Create session |
| DELETE | `/chats/{chatId}` | Delete session |
| GET | `/modal/chat/{chatId}` | Feed preview |
| GET | `/modal/feed/{feedId}` | Feed preview by ID |
| PATCH | `/chats/{chatId}/feed_preview` | Update preview settings |
| GET | `/modal/generate_title/{feedId}` | Generate title |
| POST | `/feeds/generate_title` | Generate title directly |
| PATCH | `/feeds/{feedId}` | Update feed |
| POST | `/feeds/create` | Create feed directly |

#### News/Feed API (`lib/services/news_service.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/feeds` | All feeds (metadata) |
| GET | `/feeds?feed_id={feedId}` | Feed with posts |
| GET | `/posts/feed/{feedId}?cursor=&limit=20` | Paginated posts |
| DELETE | `/users_feeds?feed_id={feedId}` | Unsubscribe |
| POST | `/feeds/rename` | Rename feed |
| POST | `/posts/seen` | Mark posts as read |
| POST | `/feeds/read_all/{feedId}` | Mark all as read |
| POST | `/feeds/summarize_unseen/{feedId}` | Create digest |
| GET | `/posts/{postId}` | Get post by ID |
| POST | `/sources/validate` | Validate source URL |
| GET | `/api/feeds/unread_counts?user_id={userId}` | Unread counts |

#### Tags API (`lib/services/tag_service.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/tags` | All tags |
| GET | `/tags/users/tags` | User's tags |

#### User API (`lib/services/auth_service.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| DELETE | `/users/me` | Delete account |

#### Feedback API (`lib/services/feedback_service.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/feedback` | Submit feedback (multipart/form-data) |

#### Notifications API (`lib/services/notification_service.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/device-tokens/` | Register FCM token |
| DELETE | `/device-tokens/` | Unregister token |

#### Telegram API (`lib/services/telegram_service.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/telegram/status` | Link status |
| GET | `/api/telegram/link-url` | Get link URL |

#### WebSocket (`lib/services/websocket_service.dart`)

| Protocol | Endpoint | Purpose |
|----------|----------|---------|
| WSS | `/ws/feeds?token={accessToken}` | Real-time post updates |

#### Data Flow
- User feeds data is fetched via backend API with nested joins: `feeds → posts → sources`
- Feed Builder requests are processed via backend API
- Feed/digest creation is handled via backend API

### Service Layer

**Core Services** (all singletons):
- `AuthService` - Authentication state, OAuth, session management
- `NewsService` - Fetch/manage news feeds from backend
- `ChatService` - HTTP client for Feed Builder API endpoints
- `ChatCacheService` - Local chat message caching
- `FeedManagementService` - Feed subscription management
- `ThemeService` - Dark/light theme persistence
- `LocaleService` - Language switching (ru/en)
- `AnalyticsService` - AppMetrica event tracking with user identification
- `NavigationService` - Global navigation state

### State Management

The app uses **ChangeNotifier pattern** for state management:
- Services extend `ChangeNotifier` and call `notifyListeners()` on state changes
- Widgets listen to services via `addListener()` and rebuild on changes
- No external state management library (no Provider, Riverpod, Bloc)

### UI Architecture

**iOS-First Design** with Cupertino widgets:
- Uses `CupertinoApp`, `CupertinoPageScaffold`, `CupertinoNavigationBar`
- Strict black/white color scheme (see `lib/theme/colors.dart`)
- Custom modal sheets for iOS-style bottom sheets
- Smooth animations and transitions

**Key Pages**:
- `lib/pages/auth_page.dart` - Login/signup with email and OAuth
- `lib/pages/home_page.dart` - News feed display
- `lib/pages/chat_page.dart` - Feed Builder interface (creates feeds and digests)
- `lib/pages/chat_list_page.dart` - Feed Builder sessions list
- `lib/pages/profile_page.dart` - User settings, theme, locale, logout
- `lib/pages/fullscreen_input_page.dart` - Fullscreen text input for chat

### Data Models

Key models in `lib/models/`:
- `chat_models.dart` - `Chat`, `ChatMessage` for Feed Builder sessions
- `news_item.dart` - `NewsItem` for news posts
- `feed_models.dart` - `Feed`, `Post`, `Source` for backend data structure

**Backend Data Structure**:
```
users_feeds (join table)
  └── feeds (1:N)
      ├── name, created_at
      └── posts (1:N)
          ├── title, summary, full_text, image_urls
          └── sources (N:M)
              └── source_url, created_at
```

### Analytics

### Yandex AppMetrica Analytics

**Service:** `lib/services/analytics_service.dart`
**Configuration:** `lib/config/appmetrica_config.dart`
**Package:** `appmetrica_plugin: ^3.4.0`
**Event Schema:** `lib/models/analytics_event_schema.dart`

**Core Features:**
- Event tracking: `capture(event, properties)` - Track custom user actions with unlimited JSON properties
- User identification: `identify(userId, properties)` - Set user profile attributes (100+ supported)
- Screen tracking: Automatic navigation tracking (no manual code required)
- API error monitoring: `captureApiError()` - Backend error tracking with rich context
- Privacy controls: `optOut()`, `optIn()`, `isOptedOut()` - GDPR/CCPA compliance with queryable state
- Crash reporting: Automatic unhandled exception and native crash capture
- Offline support: Native event queuing with automatic retry

**User Profile Attributes:**

These attributes are set once per user and persist across sessions:

- `platform` - ios/android/web/macos/windows/linux (auto-set)
- `app_version` - From pubspec.yaml, e.g., "1.0.0" (auto-set)
- `app_build` - Build number, e.g., "9" (auto-set)
- `locale` - User language code, e.g., "en", "ru" (auto-set)
- `user_id` - User UUID (set on sign-in)
- `email_hash` - SHA256 hash for privacy-safe identification (set on sign-in)

**Event Properties:**

Unlike Matomo's 10 dimension limit, AppMetrica supports **unlimited JSON properties** per event:

```dart
// Simple event
await AnalyticsService().capture(EventSchema.feedCreated);

// Event with unlimited properties (no 3-property limit!)
await AnalyticsService().capture(EventSchema.feedCreated, properties: {
  'feed_id': 'abc123',
  'feed_name': 'Tech News',
  'source_count': 5,
  'has_preview': true,
  'creation_duration_ms': 1523,
  'custom_field_1': 'value1',
  // ... add as many as needed!
});

// API error tracking with rich context
await AnalyticsService().captureApiError(
  endpoint: '/api/chats',
  statusCode: 500,
  method: 'POST',
  errorMessage: 'Internal server error',
  service: 'chat',
);
```

**User Identification:**
```dart
// Identify user after sign-in
await AnalyticsService().identify(
  userId: user.id,
  properties: {
    'email_hash': sha256Hash,
    'signup_method': 'google',
  },
);

// Reset on logout
await AnalyticsService().reset();
```

**Privacy Controls (GDPR/CCPA):**
```dart
// Check current opt-out state (now properly queryable!)
final isOptedOut = await AnalyticsService().isOptedOut();

// Opt out of tracking
await AnalyticsService().optOut();

// Opt in to tracking
await AnalyticsService().optIn();
```

**Event Naming Convention:**

AppMetrica uses descriptive Title Case event names for clarity:

- `EventSchema.userSignedIn` → "User Signed In"
- `EventSchema.feedCreated` → "Feed Created"
- `EventSchema.themeChanged` → "Theme Changed"

All events are defined in `lib/models/analytics_event_schema.dart` with validation schemas.

**Migration Benefits:**

- ✅ **Unlimited properties** - No more 3-property limit (was major Matomo issue)
- ✅ **Queryable opt-out** - `isOptedOut()` now works correctly (was hardcoded `false` in Matomo)
- ✅ **Automatic screen tracking** - Removed 90+ lines of RouteObserver code
- ✅ **Native offline queue** - Events delivered reliably even with poor connectivity
- ✅ **Rich user profiles** - 100+ profile attributes vs Matomo's 5 dimensions
- ✅ **Built-in crash reporting** - No additional service needed
- ✅ **Property validation** - EventSchema validates properties in debug mode

### Error Tracking & Monitoring

**Service:** `lib/services/error_logging_service.dart`
**Configuration:** `lib/config/glitchtip_config.dart`
**Package:** `sentry_flutter: ^9.12.0`
**Dashboard:** https://glitchtip.infra.makekod.ru

**Core Features:**
- **Automatic error capturing** - All uncaught Flutter, Dart, and platform errors
- **Manual error capturing** - `ErrorLoggingService().captureException()` for try-catch blocks
- **HTTP error tracking** - `captureHttpError()` for API failures with endpoint/status/method
- **Breadcrumbs** - User action trail leading to errors (up to 10 recent actions)
- **User context** - Automatic user ID from AuthService on sign-in
- **Device context** - Platform, OS version, app version from PackageInfo
- **Privacy filtering** - GDPR-compliant: filters API keys, JWT tokens, emails, phone numbers
- **Rate limiting** - 50 errors/min to prevent error flooding
- **Deduplication** - Fingerprint-based (error type + stack trace) to avoid duplicates
- **Performance monitoring** - 10% sampling in production (tracesSampleRate: 0.1)

**GlitchTip Infrastructure:**
- **Platform:** Self-hosted Sentry-compatible error tracking
- **URL:** https://glitchtip.infra.makekod.ru
- **Production Project ID:** 1
- **DSN:** Configured via `GLITCHTIP_DSN` environment variable
- **Full control:** All error data stays on our infrastructure (GDPR-compliant)

**Usage Examples:**

```dart
// 1. Automatic (already configured in main.dart)
// All uncaught errors are automatically sent to GlitchTip

// 2. Manual exception capture in try-catch
try {
  await fetchData();
} catch (e, stack) {
  await ErrorLoggingService().captureException(
    e,
    stack,
    context: 'news_fetch',
    extraData: {'feed_id': feedId},
    severity: ErrorSeverity.error,
  );
  rethrow;
}

// 3. HTTP error tracking
if (response.statusCode >= 400) {
  await ErrorLoggingService().captureHttpError(
    endpoint: '/api/chats',
    statusCode: response.statusCode,
    method: 'POST',
    errorMessage: response.body,
    service: 'chat',
  );
}

// 4. Add breadcrumbs (user actions)
ErrorLoggingService().addBreadcrumb(
  'send_message',
  'chat_page',
  data: {'chat_id': chatId, 'message_length': 123},
);

// 5. Set current route
ErrorLoggingService().setCurrentRoute('/home');
```

**Error Context Captured:**

Each error includes:
- **Stack trace** - Full stack trace for debugging
- **User context** - User ID (email hash for privacy)
- **Device context** - Platform (iOS/Android/Web), OS version, app version, build number
- **App context** - Current route, breadcrumbs (last 10 user actions)
- **Extra data** - Custom key-value pairs for debugging
- **Fingerprint** - For error grouping (error type + top 3 stack lines)

**Privacy & GDPR:**
- ✅ `sendDefaultPii: false` - No automatic PII collection
- ✅ Email addresses filtered to `***@***.***`
- ✅ API keys filtered to `API_KEY=***`
- ✅ JWT tokens filtered to `Bearer ***`
- ✅ Refresh tokens filtered to `rt_***`
- ✅ Phone numbers filtered to `***PHONE***`
- ✅ User email sent as hash only (`email_hash`)

**Rate Limiting & Deduplication:**
- **Rate limit:** 50 errors/minute per device (prevents error loops)
- **Deduplication:** Same error not sent twice in one session
- **Fingerprint cache:** Last 100 unique errors cached

**Dashboard Features:**
- **Issue List** - All errors grouped by fingerprint
- **Issue Details** - Stack trace, breadcrumbs, user context, extra data
- **Trends** - Error count graphs over time
- **User Impact** - How many users affected
- **Alerts** - Email/webhook notifications (configurable)

**Testing:**

```dart
// Add to ProfilePage (debug mode only)
if (kDebugMode) {
  CupertinoButton(
    child: Text('Test Error Logging'),
    onPressed: () async {
      await ErrorLoggingService().captureException(
        Exception('Test error from UI'),
        StackTrace.current,
        context: 'test',
        extraData: {'test_key': 'test_value'},
        severity: ErrorSeverity.warning,
      );
    },
  );
}
```

**Configuration:**
- DSN loaded from `GLITCHTIP_DSN` environment variable
- See `config/README.md` for setup instructions
- Full documentation: `GLITCHTIP_INTEGRATION.md`

## Platform-Specific Notes

### iOS/macOS

- **Dual Bundle ID Configuration** (parallel dev/prod installations):
  - **Development**: `com.nirssyan.makefeed.dev` - Display name: `порнахаб`
  - **Production**: `com.nirssyan.makefeed` - Display name: `infatium`
  - Configured via `ios/Flutter/Dev.xcconfig` and `ios/Flutter/Prod.xcconfig`
  - Enables simultaneous TestFlight and App Store installations
  - **Setup required**: See [`XCODE_SETUP_GUIDE.md`](./XCODE_SETUP_GUIDE.md) for Xcode configuration
- **Sign in with Apple** requires "Sign in with Apple" capability enabled in Xcode
- Check entitlements in `ios/Runner/Runner.entitlements`
- Service ID and Redirect URL must be configured in Apple Developer Console
- Native Sign in with Apple uses `sign_in_with_apple` package
- **UI Behavior**: Auth page shows both Google and Apple sign-in buttons side by side
- **Note**: Apple sign-in is automatically hidden on non-Apple platforms via `Platform.isIOS || Platform.isMacOS` check

### Android

- Minimum SDK: Check `android/app/build.gradle.kts`
- Uses Kotlin for native code
- Google Sign-In requires SHA-1 certificate fingerprint in Google Cloud Console
- SHA-1 must be registered for both debug and release keystores
- Android OAuth client ID: `715376087095-bl8qcgde9ck9bb747vrdtiuod8t2k9v4.apps.googleusercontent.com`
- **UI Behavior**: Auth page shows Google sign-in button at full width

### Web

- Deep linking for OAuth callbacks requires proper redirect URL configuration
- **UI Behavior**: Auth page shows only Google sign-in button at full width (Apple sign-in hidden)
- Google Sign-In on web requires proper OAuth client ID configuration

## Localization

Supported languages: English (en), Russian (ru)

**Adding new strings**:
1. Add to `lib/l10n/app_en.arb` and `lib/l10n/app_ru.arb`
2. Run `flutter gen-l10n` or any `flutter run/build` command
3. Use via `AppLocalizations.of(context)!.yourKey`

Generated code is in `lib/l10n/generated/`.

## Environment Variables

**Configuration system**: The app uses `config/*.local.json` files loaded via `--dart-define-from-file`. See `config/README.md` for complete documentation.

### Active Configuration Variables (9 total)

These variables are used in `lib/config/` files and affect runtime behavior:

#### Required Secret Keys (no defaults for security)

**`API_KEY`** (Secret, REQUIRED)
- **Purpose**: Backend API authentication
- **Security**: NO default value to prevent accidental exposure
- **Get from**: Backend configuration or `config/dev.local.json.example`
- **Configured in**: `lib/config/api_config.dart`
- **Validation**: App throws exception on startup if missing

**`APPMETRICA_API_KEY`** (Secret, REQUIRED)
- **Purpose**: Yandex AppMetrica analytics authentication
- **Security**: NO default value to prevent accidental exposure
- **Get from**: https://appmetrica.yandex.com/ → Application Settings → API Key
- **Configured in**: `lib/config/appmetrica_config.dart`
- **Validation**: App throws exception on startup if missing

#### Optional Public URLs (have defaults)

**`API_BASE_URL`** (Public, OPTIONAL)
- **Default**: `https://dev.api.infatium.ru`
- **Purpose**: Backend API base URL
- **Configured in**: `lib/config/api_config.dart`
- **Override for**: Different backend environment (staging/prod)

**`CUSTOM_AUTH_BASE_URL`** (Public, OPTIONAL)
- **Default**: `https://dev.api.infatium.ru/auth`
- **Purpose**: Authentication service endpoint
- **Configured in**: `lib/config/auth_config.dart`
- **Override for**: Different auth service environment

**`SHARE_BASE_URL`** (Public, OPTIONAL)
- **Default Dev**: `https://dev.infatium.ru`
- **Default Prod**: `https://infatium.ru`
- **Purpose**: Base URL for shareable news article links
- **Configured in**: `config/dev.json`, `config/prod.json`
- **Used by**: Share functionality in news detail page (`lib/pages/news_detail_page.dart`)
- **Override for**: Testing with local landing page or custom domain

**`SPLASH_TEXT`** (Public, OPTIONAL)
- **Default**: `infatium`
- **Purpose**: Splash screen typing animation text
- **Configured in**: `lib/config/app_config.dart`
- **Override for**: Custom app branding

**`ENABLE_NOTIFICATIONS`** (Public, OPTIONAL)
- **Default**: `true`
- **Purpose**: Enable/disable push notifications
- **Configured in**: `lib/config/notification_config.dart`
- **Override for**: Testing without notifications

**`ENABLE_DEBUG_LOGGING`** (Public, OPTIONAL)
- **Default Dev**: `true`
- **Default Prod**: `false`
- **Purpose**: Enable debug logging to `/debug/echo` endpoint
- **Configured in**: `lib/config/debug_config.dart`
- **Override for**: Enable remote logging in release builds (dev/staging)
- **Note**: Works independently of Flutter build mode (debug/release/profile)

### Configuration Files

**Location**: `config/` directory in project root

**Structure**:
```
config/
├── dev.json                    # Dev defaults (committed, no secrets)
├── prod.json                   # Prod defaults (committed, no secrets)
├── dev.local.json.example      # Dev template with real keys (committed)
├── prod.local.json.example     # Prod template with real keys (committed)
├── dev.local.json              # Your dev config (gitignored)
├── prod.local.json             # Your prod config (gitignored)
└── README.md                   # Complete documentation
```

**Setup**:
```bash
./scripts/setup.sh              # Creates *.local.json from examples
```

**Usage**:
```bash
# Quick run (recommended)
./scripts/run-dev.sh

# Manual run
flutter run --dart-define-from-file=config/dev.local.json

# Custom config
flutter run --dart-define-from-file=config/staging.local.json
```

### Security Best Practices

**⚠️ CRITICAL SECURITY WARNINGS:**
1. **NEVER** commit `config/*.local.json` files (they're gitignored)
2. **NEVER** hardcode secret keys in source code
3. **ALWAYS** use different keys for dev/staging/production environments
4. **ROTATE** all keys immediately if accidentally exposed
5. **VALIDATE** all required secrets on app startup (see `ApiConfig.validate()`)

**Note**: This project intentionally includes dev API keys in `config/*.example` files for convenience and faster onboarding. Production keys must never be committed.

See `SECURITY_AUDIT_REPORT.md` for detailed security analysis.

## Common Development Patterns

### Adding a new API endpoint

1. Add method to appropriate service (`ChatService`, `NewsService`, etc.)
2. Use `ApiConfig` for base URL and API key (NEVER hardcode!)
3. Include authentication headers: `X-API-Key`, `user-id`, `Authorization`
4. Handle errors with try-catch and log for debugging
5. Return typed models, not raw JSON

Example:
```dart
import '../config/api_config.dart';

class MyService {
  Future<Response> fetchData() async {
    final user = AuthService().currentUser;
    if (user == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/my-endpoint'),
      headers: {
        ...ApiConfig.commonHeaders, // Includes Content-Type and X-API-Key
        'user-id': user.id,
        'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
      },
    );
    return response;
  }
}
```

### Adding a new page

1. Create in `lib/pages/`
2. Use `CupertinoPageScaffold` for iOS-style layout
3. Pass required services via constructor (e.g., `LocaleService`)
4. Add navigation in `MainTabScaffold` or existing page
5. Register route observer for analytics if needed

### Making authenticated requests

**Always use `ApiConfig` for API credentials** (see `lib/config/api_config.dart`):

```dart
import '../config/api_config.dart';

final user = AuthService().currentUser;
if (user == null) return; // Handle unauthenticated state

// Use ApiConfig.commonHeaders for standard headers
final headers = {
  ...ApiConfig.commonHeaders, // Includes 'Content-Type' and 'X-API-Key'
  'user-id': user.id,
  'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
};

// Use ApiConfig.baseUrl for API endpoint
final url = Uri.parse('${ApiConfig.baseUrl}/endpoint');
```

## Debugging

- The app uses extensive `print()` statements for debugging (see `NewsService`, `ChatService`)
- Security events are logged via `_logSecurityEvent()` in `AuthService`
- Check console for API request/response logs including URLs, headers, bodies

## Dependencies

Key packages (see `pubspec.yaml` for full list):
- `sign_in_with_apple` - Native Apple Sign-In (iOS/macOS only)
- `appmetrica_plugin` - AppMetrica analytics
- `dio` - HTTP client
- `shared_preferences` - Local storage
- `flutter_markdown` - Markdown rendering
- `lottie` - Animations
- `loading_animation_widget` - Loading indicators

## Known Configuration

- Git branch: `master` (main branch)
- Private package: `publish_to: 'none'` in `pubspec.yaml`
- iOS/macOS app identifier configured in Xcode project
- Android package name configured in `android/app/build.gradle.kts`
- memory никогда не изменяй в кубе конфиг
- memory не запускать флатер дополнительно т к я это сам делаю чтобы протестить, можно ставить задачу мне на тестинг если надо именно
