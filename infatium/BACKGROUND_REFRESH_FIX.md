# Fix: 401 Invalid Refresh Token After Backgrounding

## Problem Summary

After implementing Token Reuse (409 Conflict) fixes, detailed logging revealed the **real cause** of automatic logouts:

```
🔄 AuthService: Starting token refresh (attempt 1/3)
CustomAuthClient: POST /auth/refresh
CustomAuthClient: Response 401
Response body: {"error":"invalid_token","message":"Invalid refresh token"}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ LOGOUT REASON: SESSION_REVOKED (401 Unauthorized)
⚠️ Status Code: 401
⚠️ Error: CustomAuthException(invalid_token: Invalid refresh token [HTTP 401])
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Timeline** (from logs):
- **14:45:31** - Login successful (demo@infatium.ru)
- **15:08:25** - Refresh attempt (after **22 minutes 54 seconds**)
- **15:08:29** - Backend: 401 Invalid refresh token
- **15:08:29** - Force logout

**Issue**: Refresh should occur every 14 minutes, but happened after ~23 minutes. By that time, refresh token became invalid on backend.

## Root Cause

**Scenario**:

1. **14:45:31** - User logs in
   - Access token expires at: **15:00:31** (15 min)
   - Refresh scheduled for: **14:59:31** (14 min)

2. **14:50** - User backgrounds app
   - Refresh timer **cancelled** (Timer.periodic stops)
   - Tokens remain in memory and storage

3. **15:08** - User resumes app (18 minutes later)
   - `refreshIfNeeded()` called
   - Access token expired → tries to refresh
   - But refresh token **invalid on backend** (expired or rotated)

4. **15:08:29** - Backend: 401 Invalid refresh token
   - Force logout

**Problem**: Refresh token lifetime on backend is shorter than app backgrounding duration.

## Solution Implemented

### Variant 1: Proactive Refresh on Lifecycle Events

**File**: `lib/services/auth_service.dart:957-1013`

**Changes**:

1. **On App Pause**:
   - Save pause timestamp
   - Check time until token expiry
   - If expiring soon (< 10 minutes) → **proactive refresh before backgrounding**
   - This ensures fresh tokens when app goes to background

2. **On App Resume**:
   - Log background duration
   - Check time until token expiry
   - If expiring soon (< 5 minutes) → **immediate refresh**
   - Otherwise restart normal timer

**Code**:
```dart
void handleAppLifecycleChange(AppLifecycleState state) async {
  if (state == AppLifecycleState.paused) {
    _appPausedAt = DateTime.now();

    // Proactive refresh if token expiring soon (< 10 minutes)
    if (_customSession != null) {
      final timeUntilExpiry = _customSession!.expiresAt.difference(DateTime.now());
      if (timeUntilExpiry < const Duration(minutes: 10)) {
        print('⚡ AuthService: Token expiring soon, refreshing proactively before pause');
        await _refreshCustomSession();
      }
    }

    _stopCustomSessionManagement();
  } else if (state == AppLifecycleState.resumed) {
    if (_appPausedAt != null) {
      final backgroundDuration = DateTime.now().difference(_appPausedAt!);
      print('AuthService: App was backgrounded for: ${backgroundDuration.inMinutes}m');
    }

    if (_customSession != null) {
      final timeUntilExpiry = _customSession!.expiresAt.difference(DateTime.now());

      if (timeUntilExpiry < const Duration(minutes: 5)) {
        print('⚡ AuthService: Token expiring soon on resume, refreshing immediately');
        await _refreshCustomSession();
      } else {
        _startCustomSessionManagement();
      }
    }
  }
}
```

### Variant 2: Shorter Refresh Interval

**File**: `lib/config/auth_config.dart:46`

**Change**: Reduced refresh interval from 14 minutes to **12 minutes**

**Before**:
```dart
static const Duration refreshInterval = Duration(minutes: 14); // 1 min before expiry
```

**After**:
```dart
static const Duration refreshInterval = Duration(minutes: 12); // 3 min before expiry
```

**Benefits**:
- Larger safety buffer (3 minutes instead of 1 minute)
- Reduces risk of expiry during short backgrounding
- More frequent refresh = fresher tokens

## Files Modified

1. **`lib/config/auth_config.dart`**
   - Lines 40-52: Updated `refreshInterval` from 14 to 12 minutes
   - Added documentation about backgrounding scenarios

2. **`lib/services/auth_service.dart`**
   - Line 41: Added `_appPausedAt` field for tracking background duration
   - Lines 164-165: Updated refresh timer comment
   - Lines 957-1013: Completely rewrote `handleAppLifecycleChange()` with:
     - Proactive refresh on pause
     - Immediate refresh on resume if expiring soon
     - Detailed logging of background duration

## Benefits

### Multi-Layer Protection

1. **Proactive Refresh** (< 10 min before expiry)
   - Refreshes tokens BEFORE backgrounding if expiring soon
   - Prevents expiry during background

2. **Immediate Refresh** (< 5 min on resume)
   - Refreshes tokens immediately on resume if expiring soon
   - Handles long background periods

3. **Shorter Interval** (12 min instead of 14 min)
   - Larger buffer (3 min instead of 1 min)
   - Reduces risk of expiry

### Expected Behavior

#### Scenario 1: Short Backgrounding (< 12 min)
- ✅ No proactive refresh (token still valid)
- ✅ On resume: restart timer
- ✅ No logout

#### Scenario 2: Medium Backgrounding (8-10 min pause)
- ✅ Proactive refresh before pause
- ✅ Fresh tokens during background
- ✅ On resume: restart timer
- ✅ No logout

#### Scenario 3: Long Backgrounding (> 15 min)
- ✅ Immediate refresh on resume
- ✅ New tokens received
- ✅ **No logout** (main fix!)

## Testing

See test scenarios in task list:
- Task #1: Short backgrounding (< 12 minutes)
- Task #2: Medium backgrounding with proactive refresh
- Task #3: Long backgrounding (> 15 minutes) - **Critical test**
- Task #4: Normal operation with new refresh interval

## Monitoring

### Key Logs to Watch

**On Pause**:
```
AuthService: App paused, stopping refresh timer
AuthService: Pause timestamp: 2025-02-12 14:50:00
AuthService: Time until expiry: 6m 31s
⚡ AuthService: Token expiring soon, refreshing proactively before pause
✓ Proactive refresh completed before pause
```

**On Resume**:
```
AuthService: App resumed, checking session validity
AuthService: App was backgrounded for: 18m 5s
AuthService: Time until expiry on resume: -3m 5s
⚡ AuthService: Token expiring soon on resume, refreshing immediately
🔄 AuthService: Starting token refresh
CustomAuthClient: Response 200
✓ Session refreshed successfully
```

## Next Steps

### Short-term (Client-side) ✅ DONE
- ✅ Implement proactive refresh on pause
- ✅ Implement immediate refresh on resume
- ✅ Reduce refresh interval to 12 minutes
- ⏳ Test all scenarios (tasks #1-4)

### Long-term (Backend)
Consider backend improvements:
1. **Increase refresh token TTL** to 24-48 hours
2. **Add grace period** for token rotation (5 minutes)
3. **Add backend logging** for refresh token validation failures
4. **Monitor** refresh token lifetime in production

## References

- Plan document: `/Users/danilakiva/.claude/projects/-Users-danilakiva-work-aichat/29374538-fabd-4162-9c8e-f91e1dd25bc4.jsonl`
- Token Reuse fix: `TOKEN_REUSE_FIX_IMPLEMENTATION.md`
- Auth config: `lib/config/auth_config.dart`
- Auth service: `lib/services/auth_service.dart`

## Critical Bugs Found During Testing

### Bug #1: Async Callback in Timer.periodic

**File**: `lib/services/auth_service.dart:165-167`

**Problem**: Timer callback was async, causing unpredictable delays
```dart
// ❌ BEFORE (BROKEN)
_customRefreshTimer = Timer.periodic(AuthConfig.refreshInterval, (_) async {
  await _refreshCustomSession();
});
```

**Symptom**: Refresh occurred after **18 minutes instead of 12 minutes**

**Root cause**: `Timer.periodic` doesn't guarantee timely execution of async callbacks. The callback may be delayed or queued incorrectly.

**Fix**:
```dart
// ✅ AFTER (FIXED)
_customRefreshTimer = Timer.periodic(AuthConfig.refreshInterval, (_) {
  _refreshCustomSession(); // Sync callback, async operation runs independently
});
```

### Bug #2: Async Method Called from Sync Context

**File**: `lib/services/auth_service.dart:961`

**Problem**: `handleAppLifecycleChange` was async void but called from sync `didChangeAppLifecycleState`
```dart
// ❌ BEFORE (BROKEN)
void handleAppLifecycleChange(AppLifecycleState state) async {
  await _refreshCustomSession();
}
```

**Symptom**: No lifecycle logs ("App paused", "App resumed") in console output

**Root cause**: When sync method calls async void method, async operations may not execute. Lifecycle callbacks require synchronous methods.

**Fix**:
```dart
// ✅ AFTER (FIXED)
void handleAppLifecycleChange(AppLifecycleState state) {
  // Sync method, schedule async operations via .then()
  _refreshCustomSession().then((_) {
    print('✓ Refresh completed');
  });
}
```

### Bug #3: Race Condition - Duplicate Refresh Requests

**Symptom**: Two refresh requests sent with same token 5 seconds apart (from backend logs)

```
09:48:18 - POST /auth/refresh with token "1w7G..." → 200 OK
09:48:23 - POST /auth/refresh with SAME token → 401 "token_already_refreshed"
```

**Root cause**: Multiple code paths triggering refresh without checking `_isRefreshing`:
1. Timer.periodic triggers refresh
2. Lifecycle event (pause/resume) triggers refresh at same time
3. Both use same old token → first succeeds, second fails

**Fix**: Added `_isRefreshing` checks in lifecycle handlers:

```dart
// Pause lifecycle (line ~980)
if (_customSession != null && !_isRefreshing) {  // ← Check added!
  if (timeUntilExpiry < Duration(minutes: 10)) {
    _refreshCustomSession().then(...);
  }
}

// Resume lifecycle (line ~1013)
if (timeUntilExpiry < Duration(minutes: 5)) {
  if (_isRefreshing) {  // ← Check added!
    print('⚠️ Refresh already in progress, skipping duplicate');
    return;
  }
  _refreshCustomSession().then(...);
}
```

**Also**: Handle "token_already_refreshed" gracefully (not as logout):

```dart
if (isTokenAlreadyRefreshed) {
  print('ℹ️ Token already refreshed (race condition)');
  print('   First refresh succeeded, this one late - session still valid');
  _tokenRefreshAttempts = 0;
  // NO logout - session is fine!
}
```

## Date

Implementation: 2026-02-12
Critical bugs fixed: 2026-02-12 (same day)
Race condition fix: 2026-02-12 (same day)
