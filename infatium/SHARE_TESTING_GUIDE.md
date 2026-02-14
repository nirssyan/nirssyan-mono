# Share Functionality Testing Guide

## Quick Setup

If you already have local config files, add the new variable:

```bash
# Option 1: Regenerate from examples (recommended)
./scripts/setup.sh

# Option 2: Manually edit existing files
# Add to config/dev.local.json:
"SHARE_BASE_URL": "https://dev.infatium.ru"

# Add to config/prod.local.json:
"SHARE_BASE_URL": "https://infatium.ru"
```

## Test Plan

### Test 1: Dev Build URL Verification

**Objective**: Confirm dev builds generate dev share URLs

```bash
# Build for iOS (dev)
./scripts/build-ios-dev.sh

# Or run directly
./scripts/run-dev.sh -d macos
```

**Steps**:
1. Open app on device/simulator
2. Navigate to any news article
3. Tap share button (top-right glass button)
4. Share to Notes app or any messenger
5. **Expected URL**: `https://dev.infatium.ru/news/{postId}`

**Pass Criteria**: URL starts with `https://dev.infatium.ru`

---

### Test 2: Prod Build URL Verification

**Objective**: Confirm prod builds generate prod share URLs

```bash
# Build for iOS (prod)
./scripts/build-ios-prod.sh
```

**Steps**:
1. Install production build on device
2. Navigate to any news article
3. Tap share button
4. Share to Notes app
5. **Expected URL**: `https://infatium.ru/news/{postId}`

**Pass Criteria**: URL starts with `https://infatium.ru`

---

### Test 3: Telegram Preview

**Objective**: Verify OG meta tags work in Telegram

**Steps**:
1. Share article from **prod build** to Telegram
2. Observe preview card in chat
3. Click preview to open landing page

**Pass Criteria**:
- ✅ Preview shows article title
- ✅ Preview shows article description/summary
- ✅ Preview shows article image (if available)
- ✅ Clicking preview opens `https://infatium.ru/news/{postId}`

---

### Test 4: WhatsApp Preview

**Objective**: Verify OG meta tags work in WhatsApp

**Steps**:
1. Share article from **prod build** to WhatsApp
2. Observe preview card in chat
3. Click preview to open landing page

**Pass Criteria**:
- ✅ Preview shows article title
- ✅ Preview shows article description
- ✅ Preview shows article image
- ✅ Clicking preview opens browser to landing page

---

### Test 5: Landing Page Rendering

**Objective**: Verify shared links load correctly in browser

**Steps**:
1. Copy share URL: `https://infatium.ru/news/{postId}`
2. Open in Safari/Chrome on mobile or desktop
3. Verify page content loads

**Pass Criteria**:
- ✅ Article title displays correctly
- ✅ Article summary/content displays
- ✅ Article image displays (if available)
- ✅ "Open in App" button is visible
- ✅ Page layout is responsive

---

### Test 6: Deep Link to App

**Objective**: Verify "Open in App" button redirects to native app

**Prerequisites**: App must be installed on device

**Steps**:
1. Open shared link in browser: `https://infatium.ru/news/{postId}`
2. Tap "Open in App" button
3. Observe app behavior

**Pass Criteria**:
- ✅ System prompts to open Makefeed app
- ✅ App opens successfully
- ✅ App navigates to the correct news article
- ✅ Deep link format: `infatium://news/{postId}`

---

### Test 7: Error Handling

**Objective**: Verify graceful error handling

**Test 7a: Missing Post ID**

**Steps**:
1. Find news item without ID (edge case)
2. Tap share button

**Pass Criteria**:
- ✅ Error dialog appears
- ✅ Message: "Cannot share" (English) or localized equivalent
- ✅ Message: "No share ID available"
- ✅ No crash, no share sheet

**Test 7b: Missing Image**

**Steps**:
1. Share article without image
2. Check Telegram/WhatsApp preview

**Pass Criteria**:
- ✅ Preview shows title and description
- ✅ Fallback OG image used (if configured)
- ✅ No broken image icon

---

### Test 8: Analytics Verification

**Objective**: Confirm share events are tracked

**Steps**:
1. Share any article (dev or prod)
2. Log into Yandex AppMetrica dashboard
3. Navigate to Events → Custom Events
4. Filter for recent events

**Pass Criteria**:
- ✅ Event `"Post Shared"` appears
- ✅ Properties include `post_id: "{uuid}"`
- ✅ Properties include `share_method: "system"`
- ✅ Event timestamp matches share action

**AppMetrica Dashboard**: https://appmetrica.yandex.com/

---

### Test 9: Cross-Platform Share

**Objective**: Verify share works on all platforms

**Platforms to Test**:
- [ ] iOS (iPhone/iPad)
- [ ] macOS
- [ ] Android (if available)
- [ ] Web (if supported)

**Steps** (for each platform):
1. Run app: `./scripts/run-dev.sh -d {platform}`
2. Open news article
3. Tap share button
4. Verify native share sheet appears
5. Share to available messengers

**Pass Criteria**:
- ✅ Share button visible and functional
- ✅ Native share sheet opens
- ✅ Share URL format correct for environment

---

### Test 10: Long Title/Description

**Objective**: Verify truncation and formatting

**Steps**:
1. Find article with very long title (100+ characters)
2. Share to Telegram
3. Observe preview card

**Pass Criteria**:
- ✅ Title truncates gracefully (ellipsis)
- ✅ Description truncates if needed
- ✅ No layout overflow
- ✅ Preview remains readable

---

## Quick Verification Commands

### Check Configuration Files
```bash
# Verify dev config has SHARE_BASE_URL
cat config/dev.local.json | grep SHARE_BASE_URL
# Expected: "SHARE_BASE_URL": "https://dev.infatium.ru"

# Verify prod config has SHARE_BASE_URL
cat config/prod.local.json | grep SHARE_BASE_URL
# Expected: "SHARE_BASE_URL": "https://infatium.ru"
```

### Build and Test
```bash
# Dev build
./scripts/run-dev.sh -d macos
# Share an article → URL should be https://dev.infatium.ru/news/{id}

# Prod build
./scripts/build-ios-prod.sh
# Share an article → URL should be https://infatium.ru/news/{id}
```

### Check Landing Page
```bash
# Test landing page responds (dev)
curl -I https://dev.infatium.ru/news/test-id
# Expected: 200 OK or 404 (if post doesn't exist)

# Test landing page responds (prod)
curl -I https://infatium.ru/news/test-id
# Expected: 200 OK or 404
```

---

## Expected Behavior Summary

| Action | Dev Build | Prod Build |
|--------|-----------|------------|
| Tap share button | Share sheet opens | Share sheet opens |
| Share URL format | `https://dev.infatium.ru/news/{postId}` | `https://infatium.ru/news/{postId}` |
| Messenger preview | Title, description, image | Title, description, image |
| Open in browser | Landing page loads | Landing page loads |
| "Open in App" button | Deep link to app | Deep link to app |
| Deep link format | `infatium://news/{postId}` | `infatium://news/{postId}` |
| Analytics event | `Post Shared` tracked | `Post Shared` tracked |

---

## Troubleshooting

### Issue: Share URL still shows staging domain
**Cause**: Local config file not updated

**Solution**:
```bash
./scripts/setup.sh  # Regenerate local config files
```

### Issue: Share button doesn't appear
**Cause**: Not on news detail page

**Solution**: Navigate to full article view (tap any news card)

### Issue: "Cannot share" error
**Cause**: News item missing ID field

**Solution**: Try different article, or check backend data

### Issue: Messenger preview doesn't show
**Cause**: Landing page OG meta tags not generated

**Solution**:
1. Verify landing page is deployed
2. Check URL in browser manually
3. Verify OG meta tags: View Page Source → search for `<meta property="og:`

### Issue: Deep link doesn't open app
**Cause**: Deep link not configured or app not installed

**Solution**:
1. Verify app is installed on device
2. Check deep link configuration:
   - iOS: `ios/Runner/Info.plist` → URL Scheme: `makefeed`
   - Android: `android/app/src/main/AndroidManifest.xml` → Intent Filter

### Issue: Analytics not tracking
**Cause**: AppMetrica not initialized or opted out

**Solution**:
1. Check `APPMETRICA_API_KEY` is set
2. Verify opt-out status: `await AnalyticsService().isOptedOut()`
3. Check AppMetrica dashboard (24-hour delay possible)

---

## Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Dev builds use dev URL | 100% | ⏳ |
| Prod builds use prod URL | 100% | ⏳ |
| Telegram previews work | 100% | ⏳ |
| WhatsApp previews work | 100% | ⏳ |
| Landing pages load | 100% | ⏳ |
| Deep links open app | 100% | ⏳ |
| Analytics tracked | 100% | ⏳ |
| No crashes during share | 100% | ⏳ |

---

## Estimated Testing Time

- **Quick smoke test** (dev build + share): ~5 minutes
- **Full test suite** (all 10 tests): ~20-30 minutes
- **Cross-platform testing** (iOS + macOS + Android): ~45 minutes

---

## Report Issues

If you encounter any issues during testing:

1. **Document**:
   - Platform (iOS/Android/macOS/Web)
   - Build type (dev/prod)
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots/screen recordings

2. **Check**:
   - Configuration files have `SHARE_BASE_URL`
   - Landing page is accessible
   - App has latest build

3. **Contact**:
   - GitHub Issues
   - Project Discord/Slack
   - Backend team (if API issues)

---

## Notes

- Testing on **production builds** requires signing certificates and provisioning profiles
- **Messenger previews** may cache OG meta tags (wait 5-10 minutes for updates)
- **Deep links** require app to be installed on the test device
- **Analytics** may have a delay (up to 24 hours in AppMetrica)

**Date Created**: 2026-02-09
**Last Updated**: 2026-02-09
