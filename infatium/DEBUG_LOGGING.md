# Debug Logging to Remote Endpoint

## Overview

In **debug mode**, all application logs (print statements) are automatically sent to the debug endpoint for remote monitoring and debugging.

## Endpoint

```
POST /debug/echo
```

**Base URL**: Configured via `API_BASE_URL` (default: `https://dev.api.infatium.ru`)

**Full URL**: `https://dev.api.infatium.ru/debug/echo`

## Features

✅ **Automatic capture** - All `print()` statements are intercepted
✅ **Console passthrough** - Logs still appear in console (not affected)
✅ **Batch sending** - Logs are batched for efficiency
✅ **Config-controlled** - Enabled via `ENABLE_DEBUG_LOGGING` flag (dev: true, prod: false)
✅ **Works in release builds** - Can enable debug logging in TestFlight/staging builds
✅ **Non-blocking** - Logging failures don't crash the app
✅ **Memory safe** - Auto-flush at 100 logs to prevent memory issues
✅ **Periodic flush** - Sends logs every 5 seconds

## Request Format

**Method**: `POST`

**Headers**:
```json
{
  "Content-Type": "application/json"
}
```

**Body**:
```json
{
  "source": "flutter_app",
  "timestamp": "2026-02-13T14:30:00.000Z",
  "logs": [
    "[2026-02-13T14:30:00.123] AuthService: Starting token refresh",
    "[2026-02-13T14:30:01.456] CustomAuthClient: POST /refresh",
    "[2026-02-13T14:30:02.789] ✅ Token refresh successful"
  ],
  "count": 3
}
```

## Implementation

### Service

**File**: `lib/services/debug_log_service.dart`

**Key methods**:
- `startCapturingLogs(Function appInitializer)` - Start capturing all print() calls
- `stop()` - Stop capturing and flush remaining logs
- `dispose()` - Clean up resources

### Integration

**File**: `lib/main.dart`

```dart
void main() async {
  // Enable debug logging in debug mode OR if explicitly enabled in config
  if (kDebugMode || DebugConfig.enableDebugLogging) {
    DebugLogService().startCapturingLogs(_initializeApp);
  } else {
    _initializeApp();
  }
}
```

The service uses `runZoned()` to intercept all `print()` calls and sends them to the debug endpoint.

## Configuration

Debug logging can be enabled in two ways:

1. **Debug Mode** (`kDebugMode`): Automatically enabled when running with `flutter run` (debug mode)
2. **Config Flag** (`ENABLE_DEBUG_LOGGING`): Explicitly enable in config files

**Config files**:
- `config/dev.json`: Set `"ENABLE_DEBUG_LOGGING": "true"` to enable in dev builds
- `config/prod.json`: Set `"ENABLE_DEBUG_LOGGING": "false"` to disable in prod builds

This allows debug logging to work in **release builds** for dev environment, while keeping it disabled in production.

**Runtime condition** (`lib/main.dart`):
```dart
if (kDebugMode || DebugConfig.enableDebugLogging) {
  DebugLogService().startCapturingLogs(_initializeApp);
}
```

**Service parameters**:
- **Buffer size**: 100 logs (force flush when reached)
- **Flush interval**: 5 seconds
- **Request timeout**: 5 seconds

## Startup Logs

When debug logging is enabled, you'll see:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Debug Logging: ENABLED
📋 All app logs → POST https://dev.api.infatium.ru/debug/echo
📋 Batch size: 100 logs or every 5 seconds
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Backend Requirements

The debug endpoint should:
1. Accept POST requests without authentication
2. Accept any JSON body
3. Log the received data
4. Return 200 OK (response body is ignored)

Example backend implementation (conceptual):
```python
@app.post("/debug/echo")
async def debug_echo(body: dict):
    logger.info(f"Debug logs received: {body}")
    return {"status": "ok"}
```

## Usage Example

Any `print()` statement in the app will be captured:

```dart
// In your code
print('AuthService: Starting token refresh');

// This will:
// 1. Appear in console as usual
// 2. Be buffered by DebugLogService
// 3. Be sent to POST /debug/echo within 5 seconds (or when buffer reaches 100 logs)
```

## Troubleshooting

**Logs not appearing on backend?**
- Check that debug logging is enabled:
  - **Option 1**: Run with `flutter run` (debug mode, `kDebugMode = true`)
  - **Option 2**: Set `ENABLE_DEBUG_LOGGING: true` in config file (works in release builds too)
- Verify `API_BASE_URL` is correct in your config
- Check network connectivity
- Verify debug endpoint is accepting requests (no auth required)

**App performance issues?**
- Debug logging is designed to be non-blocking
- Logs are batched to minimize network requests
- Failed requests are silently ignored (won't crash app)
- Buffer is limited to 100 logs (auto-flush)

**Want to disable temporarily?**
- Comment out the `DebugLogService().startCapturingLogs()` call in `main.dart`
- Or set a custom flag: `const enableDebugLogging = false;` and wrap the call

## Production

⚠️ **Important**: Debug logging is **controlled via config files**.

**Production safety**:
- `config/prod.json` has `ENABLE_DEBUG_LOGGING: false` → No debug logging in prod
- `config/dev.json` has `ENABLE_DEBUG_LOGGING: true` → Debug logging works even in release builds

This ensures that:
- **Dev release builds** (TestFlight, staging) → Debug logging enabled ✅
- **Prod release builds** (App Store) → Debug logging disabled ❌
- **Debug mode** (`flutter run`) → Debug logging always enabled ✅

## Privacy

The debug logging service sends **raw logs** to the backend, which may contain sensitive information. This is acceptable for debug/development builds, but:

- ✅ Disabled in production (enforced by `kDebugMode` check)
- ⚠️ Don't use debug builds with real user data
- ⚠️ Use staging/dev environments for debug logging
- ✅ Backend should have appropriate access controls even though endpoint requires no auth

For production error tracking, use **GlitchTip** (Sentry) which has built-in privacy filters.
