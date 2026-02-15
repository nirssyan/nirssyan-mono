# Xcode Manual Configuration Guide
## Enabling Parallel Dev and Prod iOS Installations

⚠️ **CRITICAL**: The following steps MUST be done manually in Xcode. Automated editing of `project.pbxproj` is extremely fragile and error-prone.

**Note**: OAuth configuration (Google and Apple) is shared between dev and prod. No additional OAuth setup required.

## What This Achieves

After completing these steps, you'll be able to:
- ✅ Install both **App Store (prod)** and **TestFlight (dev)** versions simultaneously on your iPhone
- ✅ See two separate apps on Home Screen: `infatium` and `порнахаб`
- ✅ Run different environments side-by-side with separate data sandboxes
- ✅ Test production and development builds without constant reinstallation

## Prerequisites

All automated configuration files have been created:
- ✅ `ios/Flutter/Dev.xcconfig` (Bundle ID: `com.nirssyan.makefeed.dev`)
- ✅ `ios/Flutter/Prod.xcconfig` (Bundle ID: `com.nirssyan.makefeed`)
- ✅ `ios/Runner/Info.plist` (updated to use `$(APP_DISPLAY_NAME)`)
- ✅ `ios/ExportOptionsDev.plist`
- ✅ `ios/ExportOptionsProd.plist`
- ✅ `scripts/build-ios-dev.sh` (updated)
- ✅ `scripts/build-ios-prod.sh` (updated)

## Step 1: Open Xcode Project

```bash
open ios/Runner.xcworkspace
```

⚠️ **Important**: Open `.xcworkspace`, NOT `.xcodeproj` (CocoaPods requirement)

## Step 2: Create Dev and Prod Build Configurations

1. **Select the project**:
   - In left sidebar (Project Navigator), click the **blue `Runner` icon** (top-level project)
   - You should see the project settings panel on the right

2. **Open Info tab**:
   - In the project settings panel, select the **`Info`** tab at the top
   - Scroll down to find **"Configurations"** section

3. **Duplicate Release configuration for Dev**:
   - Under "Configurations", expand the **`Release`** configuration
   - Click the **`+` button** below the configurations list
   - Select **"Duplicate 'Release' Configuration"**
   - Name it: **`Dev`** (exactly as shown, case-sensitive)

4. **Duplicate Release configuration for Prod**:
   - Click the **`+` button** again
   - Select **"Duplicate 'Release' Configuration"**
   - Name it: **`Prod`** (exactly as shown, case-sensitive)

**Result**: You should now see 5 configurations:
- Debug
- Release
- Profile
- **Dev** ← new
- **Prod** ← new

## Step 3: Link Configurations to xcconfig Files

1. **Still in Info tab**:
   - Find the **`Dev`** configuration row
   - Look for columns: "Runner" (target) and "Pods-Runner" (pods)

2. **Set Dev configuration**:
   - Click on the dropdown in the **"Runner"** column for **`Dev`** row
   - Select: **`Flutter/Dev`** (this links to `ios/Flutter/Dev.xcconfig`)

3. **Set Prod configuration**:
   - Click on the dropdown in the **"Runner"** column for **`Prod`** row
   - Select: **`Flutter/Prod`** (this links to `ios/Flutter/Prod.xcconfig`)

**Result**:
- `Dev` configuration → linked to `Flutter/Dev.xcconfig` (Bundle ID: `com.nirssyan.makefeed.dev`)
- `Prod` configuration → linked to `Flutter/Prod.xcconfig` (Bundle ID: `com.nirssyan.makefeed`)

## Step 4: Verify Bundle IDs (Optional but Recommended)

1. **Select the Runner target**:
   - In left sidebar, still on the blue `Runner` project
   - In the middle panel, under **"TARGETS"**, select **`Runner`**

2. **Go to Build Settings**:
   - Select **`Build Settings`** tab
   - Make sure **"All"** and **"Combined"** are selected at the top

3. **Search for Bundle Identifier**:
   - In the search box, type: **`bundle identifier`**
   - Find **"Product Bundle Identifier"** row

4. **Verify values**:
   - Expand the **"Product Bundle Identifier"** row to see all configurations
   - You should see (these come from the xcconfig files):
     - **Dev**: `com.nirssyan.makefeed.dev`
     - **Prod**: `com.nirssyan.makefeed`
     - **Debug**: `com.nirssyan.makefeed` (unchanged)
     - **Release**: `com.nirssyan.makefeed` (unchanged)

5. **Search for Display Name**:
   - In the search box, type: **`display name`**
   - Find **"APP_DISPLAY_NAME"** (User-Defined setting from xcconfig)
   - Verify values:
     - **Dev**: `порнахаб`
     - **Prod**: `infatium`

## Step 5: Create Build Schemes for Dev and Prod

### Create Dev Scheme

1. **Manage Schemes**:
   - Xcode menu bar: **`Product`** → **`Scheme`** → **`Manage Schemes...`**

2. **Duplicate Runner scheme**:
   - Select the **`Runner`** scheme
   - Click the **gear icon (⚙️)** at the bottom
   - Select **"Duplicate"**
   - Name it: **`Runner-Dev`**
   - ✅ Make sure **"Shared"** checkbox is **checked**
   - Click **"Close"**

3. **Edit Runner-Dev scheme**:
   - With `Runner-Dev` scheme selected, click **"Edit..."** button (or double-click the scheme)
   - In the left sidebar, select **`Archive`** action
   - Change **"Build Configuration"** dropdown to: **`Dev`**
   - Click **"Close"**

### Create Prod Scheme

1. **Duplicate Runner scheme again**:
   - Click **"Manage Schemes..."** again
   - Select the **`Runner`** scheme (original)
   - Click the **gear icon (⚙️)** → **"Duplicate"**
   - Name it: **`Runner-Prod`**
   - ✅ Make sure **"Shared"** checkbox is **checked**
   - Click **"Close"**

2. **Edit Runner-Prod scheme**:
   - With `Runner-Prod` scheme selected, click **"Edit..."**
   - In the left sidebar, select **`Archive`** action
   - Change **"Build Configuration"** dropdown to: **`Prod`**
   - Click **"Close"**

**Result**: You now have 3 schemes:
- **`Runner`** → Archives with `Release` config (unchanged, can be used for dev too)
- **`Runner-Dev`** → Archives with `Dev` config (Bundle ID: `com.nirssyan.makefeed.dev`)
- **`Runner-Prod`** → Archives with `Prod` config (Bundle ID: `com.nirssyan.makefeed`)

## Step 6: Test Xcode Configuration

1. **Select Runner-Dev scheme**:
   - Xcode menu bar: **`Product`** → **`Scheme`** → **`Runner-Dev`**
   - Or click the scheme selector next to the Run/Stop buttons

2. **Archive Dev build**:
   - Xcode menu bar: **`Product`** → **`Archive`**
   - Wait for build to complete
   - In Organizer window, verify:
     - App name: **`порнахаб`**
     - Bundle ID: **`com.nirssyan.makefeed.dev`** (click "Show in Finder" → Get Info to verify)

3. **Select Runner-Prod scheme**:
   - Switch to **`Runner-Prod`** scheme

4. **Archive Prod build**:
   - **`Product`** → **`Archive`**
   - Verify in Organizer:
     - App name: **`infatium`**
     - Bundle ID: **`com.nirssyan.makefeed`**

## What the Build Scripts Now Do

### Dev Build Script

```bash
./scripts/build-ios-dev.sh
```

This script will:
1. Load configuration from `config/dev.local.json`
2. Use export options from `ios/ExportOptionsDev.plist`
3. **Automatically use the Dev xcconfig** (Bundle ID: `com.nirssyan.makefeed.dev`)
4. Create IPA with display name: **`порнахаб`**

### Prod Build Script

```bash
./scripts/build-ios-prod.sh
```

This script will:
1. Load configuration from `config/prod.local.json`
2. Use export options from `ios/ExportOptionsProd.plist`
3. **Automatically use the Prod xcconfig** (Bundle ID: `com.nirssyan.makefeed`)
4. Create IPA with display name: **`infatium`**

⚠️ **Note**: Flutter's `flutter build ipa` command uses the **first Release-like configuration** it finds alphabetically. Since we named them `Dev` and `Prod`, Flutter will use `Dev` by default. For production builds, you may need to manually archive in Xcode using the `Runner-Prod` scheme, or use the `--export-options-plist` flag to specify the correct configuration.

## Next Steps: Apple Developer Setup

After completing the Xcode configuration, you need to:

### 1. Register Dev Bundle ID in Apple Developer Portal

1. Go to: https://developer.apple.com/account/resources/identifiers/list
2. Click **`+`** to add new Identifier
3. Select **"App IDs"** → Continue
4. Type: **"App"** → Continue
5. **Description**: `Makefeed Development`
6. **Bundle ID**: **Explicit** → `com.nirssyan.makefeed.dev`
7. **Capabilities**: Enable the same as production:
   - ✅ Sign in with Apple
   - ✅ Push Notifications
   - ✅ Associated Domains
8. Click **"Continue"** → **"Register"**

### 2. Create Provisioning Profiles

1. Go to: https://developer.apple.com/account/resources/profiles/list
2. Click **`+`** to create new profile
3. **Distribution** → **App Store** → Continue
4. Select **App ID**: `com.nirssyan.makefeed.dev`
5. Select your **Distribution Certificate**
6. **Profile Name**: `Makefeed Dev App Store`
7. Click **"Generate"**
8. **Download** and **double-click** to install in Xcode

### 3. App Store Connect Setup

**Option A: Separate App Entry (Recommended for TestFlight)**
1. Go to: https://appstoreconnect.apple.com/apps
2. Click **`+`** → **"New App"**
3. **Platform**: iOS
4. **Name**: `порнахаб` (or keep same name, Bundle ID is what matters)
5. **Bundle ID**: Select `com.nirssyan.makefeed.dev`
6. **SKU**: `makefeed-dev`
7. **User Access**: Full Access
8. Submit

**Option B: TestFlight Only**
- You can upload dev builds to the same App Store Connect app entry
- TestFlight will differentiate by Bundle ID
- Users will see both apps in TestFlight

### 4. OAuth Configuration (NOT REQUIRED) ✅

**⚠️ SKIP THIS STEP**: OAuth is already configured and works with both Bundle IDs.

The app uses:
- **Google OAuth**: Web client ID (serverClientId) - works with all Bundle IDs
- **Apple Sign In**: Shared Service ID - works with all Bundle IDs in your Team

**No changes needed**:
- ❌ Do NOT create separate Google OAuth client IDs for dev
- ❌ Do NOT add dev Bundle ID to Apple Service ID
- ❌ Do NOT modify `lib/services/auth_service.dart`

**Why it works**: Both Google and Apple OAuth are configured at the account/project level, not per Bundle ID. Your existing production OAuth configuration will work for both `com.nirssyan.makefeed` and `com.nirssyan.makefeed.dev`.

### 5. APNs Setup (if using Push Notifications)

1. Go to: https://developer.apple.com/account/resources/authkeys/list
2. Create new **APNs Key** (or reuse existing)
3. Upload to Firebase/Backend for both:
   - `com.nirssyan.makefeed` (prod)
   - `com.nirssyan.makefeed.dev` (dev)

## Verification Checklist

After completing all steps:

- [ ] Xcode shows 5 build configurations (Debug, Release, Profile, Dev, Prod)
- [ ] Dev configuration linked to `Flutter/Dev.xcconfig`
- [ ] Prod configuration linked to `Flutter/Prod.xcconfig`
- [ ] Three schemes exist: Runner, Runner-Dev, Runner-Prod
- [ ] Runner-Dev archives with Bundle ID `com.nirssyan.makefeed.dev`
- [ ] Runner-Prod archives with Bundle ID `com.nirssyan.makefeed`
- [ ] Dev Bundle ID registered in Apple Developer Portal
- [ ] Provisioning profiles created and installed
- [ ] App Store Connect configured (if needed)

## Building and Uploading

### Dev Build (TestFlight)

```bash
./scripts/build-ios-dev.sh
```

Or manually in Xcode:
1. Select **`Runner-Dev`** scheme
2. **`Product`** → **`Archive`**
3. **Distribute App** → **App Store Connect** → **Upload**

### Prod Build (App Store)

```bash
./scripts/build-ios-prod.sh
```

Or manually in Xcode:
1. Select **`Runner-Prod`** scheme
2. **`Product`** → **`Archive`**
3. **Distribute App** → **App Store Connect** → **Upload**

## Installing on iPhone

1. **Install Dev build**:
   - Upload to App Store Connect
   - Go to TestFlight
   - Install on iPhone
   - App appears as: **`порнахаб`**

2. **Install Prod build**:
   - Upload to App Store (or TestFlight for testing)
   - Install on iPhone
   - App appears as: **`infatium`**

3. **Verify**:
   - Both apps should be visible on Home Screen
   - Can run simultaneously
   - Separate data/sandboxes

## Troubleshooting

### "No matching provisioning profiles found"

**Solution**: Create and download provisioning profile for `com.nirssyan.makefeed.dev` from Apple Developer Portal.

### "Code signing error: The Bundle ID is invalid"

**Solution**: Verify Bundle ID is registered in Apple Developer Portal and matches exactly: `com.nirssyan.makefeed.dev`

### Both apps open from magic link

**Solution**: Consider using different deep link schemes:
- Dev: `makefeeddev://auth/callback`
- Prod: `makefeed://auth/callback`

Update `ios/Runner/Info.plist` `CFBundleURLSchemes` to use different schemes per configuration.

### Flutter builds wrong configuration

**Solution**: `flutter build ipa` uses the first Release-like config alphabetically. Options:
1. Rename configs (e.g., `AaaReleaseDev`, `ZzzReleaseProd`)
2. Use Xcode Archive instead of `flutter build ipa`
3. Use `--flavor` flag (requires additional Flutter configuration)

### OAuth doesn't work in dev app

**Solution**: This should not happen - OAuth is shared between dev and prod. If you encounter OAuth issues:
1. Verify both apps are using the same `lib/services/auth_service.dart` configuration
2. Check that Google OAuth serverClientId is set correctly (web client ID)
3. Ensure Apple Sign In Service ID is configured in Apple Developer Portal
4. Both Bundle IDs should work with existing OAuth configuration without modification

## Support

If you encounter issues:
1. Check Xcode build logs for specific errors
2. Verify all configurations in Xcode Build Settings
3. Ensure provisioning profiles are up to date
4. Check App Store Connect for upload status

## Summary

You've successfully configured parallel dev and prod iOS builds! 🎉

**Next time you want to build**:
- Dev: `./scripts/build-ios-dev.sh` → Upload to TestFlight
- Prod: `./scripts/build-ios-prod.sh` → Upload to App Store

Both apps can now coexist on your iPhone with different Bundle IDs and display names.
