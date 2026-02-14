# Share Functionality Implementation Summary

## Overview

This document summarizes the implementation of environment-based share URL configuration for the Makefeed Flutter app's news sharing functionality.

## Problem Statement

The app's share functionality was using a hardcoded staging URL (`https://infatium-nu.vercel.app`) as the default value, while production should use `https://infatium.ru`. This caused:
- Inconsistent branding (staging vs production domains)
- SEO and analytics split between two domains
- Confusion for users receiving shared links

## Solution

Added `SHARE_BASE_URL` as the 7th environment variable in the app's configuration system, enabling environment-specific share URLs:
- **Dev builds**: `https://dev.infatium.ru`
- **Prod builds**: `https://infatium.ru`

## Changes Made

### 1. Configuration Files Updated

#### `config/dev.json`
- Added: `"SHARE_BASE_URL": "https://dev.infatium.ru"`

#### `config/prod.json`
- Added: `"SHARE_BASE_URL": "https://infatium.ru"`

#### `config/dev.local.json.example`
- Added: `"SHARE_BASE_URL": "https://dev.infatium.ru"`

#### `config/prod.local.json.example`
- Added: `"SHARE_BASE_URL": "https://infatium.ru"`

### 2. Documentation Updated

#### `config/README.md`
- Added `SHARE_BASE_URL` to the "Optional (have defaults)" variables table
- Documented dev and prod default values

#### `CLAUDE.md`
- Updated "Active configuration variables" table (added 7th variable)
- Updated count from "6 total" to "7 total"
- Added detailed documentation in "Optional Public URLs" section:
  - Default values for dev/prod
  - Purpose and usage
  - Configuration location
  - Override instructions

## How It Works

### Share Flow

1. **User taps share button** on news detail page (`lib/pages/news_detail_page.dart:223-278`)
2. **App validates** post has ID (shows error dialog if missing)
3. **Generates share URL**:
   ```dart
   const String shareBaseUrl = String.fromEnvironment(
     'SHARE_BASE_URL',
     defaultValue: 'https://infatium-nu.vercel.app',  // Fallback for safety
   );
   final shareUrl = '$shareBaseUrl/news/$postId';
   ```
4. **Opens native share sheet** (iOS/Android)
5. **Tracks analytics event**: `EventSchema.postShared`

### Build Process

#### Development Build
```bash
./scripts/run-dev.sh
# Uses config/dev.local.json → SHARE_BASE_URL=https://dev.infatium.ru
```

#### Production Build
```bash
./scripts/build-ios-prod.sh
# Uses config/prod.local.json → SHARE_BASE_URL=https://infatium.ru
```

### Generated Share URLs

| Build Type | Share URL Format |
|------------|------------------|
| Dev | `https://dev.infatium.ru/news/{postId}` |
| Prod | `https://infatium.ru/news/{postId}` |

## Verification Checklist

### Configuration Files
- [x] `config/dev.json` has `SHARE_BASE_URL: https://dev.infatium.ru`
- [x] `config/prod.json` has `SHARE_BASE_URL: https://infatium.ru`
- [x] `config/dev.local.json.example` includes SHARE_BASE_URL
- [x] `config/prod.local.json.example` includes SHARE_BASE_URL

### Documentation
- [x] `config/README.md` documents SHARE_BASE_URL
- [x] `CLAUDE.md` lists SHARE_BASE_URL in active variables table
- [x] `CLAUDE.md` has detailed documentation in "Optional Public URLs"
- [x] Variable count updated from 6 to 7

### Testing Needed (Manual)

#### Phase 1: Build Verification
- [ ] Run dev build: `./scripts/build-ios-dev.sh`
  - [ ] Check build log confirms SHARE_BASE_URL=https://dev.infatium.ru
- [ ] Run prod build: `./scripts/build-ios-prod.sh`
  - [ ] Check build log confirms SHARE_BASE_URL=https://infatium.ru

#### Phase 2: Share Flow Testing
- [ ] Dev build: Open news detail page with image
  - [ ] Tap share button (top-right glass button)
  - [ ] Verify native share sheet opens
  - [ ] Share to Notes app
  - [ ] Verify URL: `https://dev.infatium.ru/news/{postId}`

- [ ] Prod build: Same test
  - [ ] Verify URL: `https://infatium.ru/news/{postId}`

#### Phase 3: Messenger Preview Testing
- [ ] Share link to **Telegram**
  - [ ] Verify preview card shows: title, description, image
  - [ ] Click preview → opens landing page

- [ ] Share link to **WhatsApp**
  - [ ] Verify preview card displays properly
  - [ ] Click preview → opens landing page

#### Phase 4: Landing Page Testing
- [ ] Open shared link in browser
  - [ ] Verify article loads with full content
  - [ ] Verify OG meta tags are correct
  - [ ] Verify "Open in App" button appears
  - [ ] Tap button → should trigger deep link: `infatium://news/{postId}`
  - [ ] Confirm app opens to correct news item

#### Phase 5: Edge Cases
- [ ] Test sharing news without image
  - [ ] Verify fallback OG image works

- [ ] Test sharing news with very long title
  - [ ] Verify title truncation in preview

- [ ] Test error handling
  - [ ] Try sharing news without ID (should show error dialog)

#### Phase 6: Analytics Verification
- [ ] Check Yandex AppMetrica dashboard
  - [ ] Verify `EventSchema.postShared` events appear
  - [ ] Verify properties: `post_id`, `share_method: 'system'`

## Technical Details

### Share Button Implementation
**Location**: `lib/pages/news_detail_page.dart:223-278`

**Features**:
- ✅ Post ID validation with bilingual error messages (EN/RU)
- ✅ Haptic feedback (medium impact)
- ✅ Native share sheet with subject line (article title)
- ✅ Share position origin for iOS 16+ Liquid Glass effect
- ✅ Analytics tracking (`EventSchema.postShared`)
- ✅ Error handling with try-catch

### Landing Page Integration
**Repository**: makefeed-landing (Next.js 15.5.9)
**Route**: `/news/[postId]/page.tsx`

**Features**:
- ✅ Dynamic OG meta tag generation per post
- ✅ Auto-generated OG images (1200x630px) via Next.js ImageResponse
- ✅ JSON-LD structured data (NewsArticle schema)
- ✅ Deep link button: `infatium://news/{postId}`
- ✅ Messenger support: Telegram, WhatsApp, Facebook, Twitter/X, iMessage

### Security & Privacy
- ✅ Share URLs use post ID only (no user data)
- ✅ No authentication required to view shared articles
- ✅ Analytics tracks share events (with user consent)
- ✅ No PII exposed in share URLs

## Migration Impact

### Before (Hardcoded Staging URL)
```dart
const String shareBaseUrl = String.fromEnvironment(
  'SHARE_BASE_URL',
  defaultValue: 'https://infatium-nu.vercel.app',  // Staging
);
```
**Result**: All builds (dev and prod) shared staging links

### After (Environment-Based URLs)
```dart
const String shareBaseUrl = String.fromEnvironment(
  'SHARE_BASE_URL',
  defaultValue: 'https://infatium-nu.vercel.app',  // Fallback only
);
```
**Result**:
- Dev builds share `https://dev.infatium.ru/news/{postId}`
- Prod builds share `https://infatium.ru/news/{postId}`
- Fallback URL only used if config is missing (safety net)

## Benefits

1. **Consistent Branding**: Production users see production domain
2. **SEO Optimization**: All production shares point to production domain
3. **Analytics Clarity**: No split between staging/production domains
4. **Environment Parity**: Dev environment uses dev landing page
5. **Flexible Testing**: Can override with custom domains if needed

## Configuration System Integration

The `SHARE_BASE_URL` variable follows the same pattern as existing public URL variables:

| Variable | Type | Default Dev | Default Prod |
|----------|------|-------------|--------------|
| `API_BASE_URL` | Public | `https://dev.api.infatium.ru` | `https://api.infatium.ru` |
| `CUSTOM_AUTH_BASE_URL` | Public | `https://dev.api.infatium.ru/auth` | `https://api.infatium.ru/auth` |
| **`SHARE_BASE_URL`** | **Public** | **`https://dev.infatium.ru`** | **`https://infatium.ru`** |

**Consistency**: All URL variables now have environment-specific defaults.

## Next Steps (User Testing)

1. **Run existing local config**:
   ```bash
   # If you already have config/dev.local.json
   # You need to add SHARE_BASE_URL to it

   # Option 1: Regenerate from example
   ./scripts/setup.sh

   # Option 2: Manually add to existing file
   # Edit config/dev.local.json and add:
   # "SHARE_BASE_URL": "https://dev.infatium.ru"
   ```

2. **Test dev build**:
   ```bash
   ./scripts/run-dev.sh
   # Share a news item and verify URL
   ```

3. **Test prod build**:
   ```bash
   ./scripts/build-ios-prod.sh
   # Share a news item and verify URL
   ```

4. **Verify messenger previews**:
   - Share to Telegram
   - Share to WhatsApp
   - Confirm OG meta tags display correctly

## Estimated Time Investment

- ✅ Configuration updates: **10 minutes** (COMPLETE)
- ✅ Documentation updates: **10 minutes** (COMPLETE)
- ⏳ Manual testing: **15 minutes** (PENDING USER)
- **Total**: ~35 minutes (25 minutes complete, 10-15 minutes user testing)

## Notes

- **No code changes required**: `lib/pages/news_detail_page.dart` already uses `String.fromEnvironment('SHARE_BASE_URL')`
- **Backward compatible**: Fallback URL still points to staging (safe default)
- **Zero breaking changes**: Existing share functionality continues to work
- **User action required**: Update local config files or run `./scripts/setup.sh`

## Related Files

### Modified
- `config/dev.json`
- `config/prod.json`
- `config/dev.local.json.example`
- `config/prod.local.json.example`
- `config/README.md`
- `CLAUDE.md`

### Referenced (No Changes)
- `lib/pages/news_detail_page.dart` (share functionality)
- `lib/services/analytics_service.dart` (tracking)
- `lib/models/analytics_event_schema.dart` (event definition)

### External Dependencies
- **makefeed-landing** repository (Next.js landing page)
  - Route: `/news/[postId]/page.tsx`
  - OG meta tag generation
  - Deep link handling

## Success Criteria

1. ✅ Configuration files contain `SHARE_BASE_URL`
2. ✅ Documentation updated and accurate
3. ⏳ Dev build generates dev share URLs
4. ⏳ Prod build generates prod share URLs
5. ⏳ Messenger previews show OG meta tags
6. ⏳ Landing page loads shared articles
7. ⏳ Deep link opens app successfully
8. ⏳ Analytics events tracked correctly

## Implementation Date

**Date**: 2026-02-09
**Environment**: macOS (Darwin 24.6.0)
**Flutter Version**: 3.24+
**Dart Version**: 3.8.1+
