# Parallel iOS Installation Setup - Quick Summary

## What Was Done (Automated)

✅ Created configuration files:
- `ios/Flutter/Dev.xcconfig` - Dev Bundle ID: `com.nirssyan.makefeed.dev`
- `ios/Flutter/Prod.xcconfig` - Prod Bundle ID: `com.nirssyan.makefeed`
- `ios/ExportOptionsDev.plist` - Dev export settings
- `ios/ExportOptionsProd.plist` - Prod export settings

✅ Updated files:
- `ios/Runner/Info.plist` - Display name now uses `$(APP_DISPLAY_NAME)` variable
- `scripts/build-ios-dev.sh` - Enhanced with Bundle ID info
- `scripts/build-ios-prod.sh` - Enhanced with Bundle ID info

## What You Need to Do (Manual)

### 1. Xcode Configuration (~15 minutes)

**Follow the detailed guide**: [`XCODE_SETUP_GUIDE.md`](./XCODE_SETUP_GUIDE.md)

**Quick steps**:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Create `Dev` and `Prod` build configurations (duplicate Release)
3. Link configurations to xcconfig files
4. Create `Runner-Dev` and `Runner-Prod` schemes
5. Verify Bundle IDs

### 2. Apple Developer Portal (~30 minutes)

**Required actions**:
1. Register Bundle ID: `com.nirssyan.makefeed.dev`
2. Create provisioning profile for dev Bundle ID
3. Download and install provisioning profile in Xcode

**Optional** (if using separate TestFlight app):
4. Create new App Store Connect entry for dev builds

### 3. OAuth Updates (if needed)

**Google OAuth** (if using platform-specific client IDs):
- Register new iOS client ID for `com.nirssyan.makefeed.dev`

**Apple Sign In**:
- Add `com.nirssyan.makefeed.dev` to allowed Service IDs

## Result

After completing all steps:

📱 **Two apps on your iPhone**:
- `infatium` (prod) - Bundle ID: `com.nirssyan.makefeed`
- `infatium DEV` (dev) - Bundle ID: `com.nirssyan.makefeed.dev`

🔄 **Easy building**:
```bash
./scripts/build-ios-dev.sh   # Dev build for TestFlight
./scripts/build-ios-prod.sh  # Prod build for App Store
```

✨ **Benefits**:
- Side-by-side testing without reinstalling
- Separate data sandboxes (different users, feeds, auth)
- Visual distinction with "DEV" suffix
- Test production while developing

## Current Status

- ✅ **Automated configuration**: Complete
- ⏳ **Manual Xcode setup**: **Required - follow XCODE_SETUP_GUIDE.md**
- ⏳ **Apple Developer setup**: **Required before uploading**

## Next Step

👉 **Open the detailed guide**: [`XCODE_SETUP_GUIDE.md`](./XCODE_SETUP_GUIDE.md)

The guide includes:
- Step-by-step Xcode instructions with screenshots descriptions
- Apple Developer Portal setup
- OAuth configuration
- Troubleshooting
- Verification checklist

## Important Notes

⚠️ **Deep Link Conflict**: Both apps currently respond to `makefeed://` scheme. iOS may open the wrong app for magic links. Consider using:
- Dev: `makefeeddev://auth/callback`
- Prod: `makefeed://auth/callback`

⚠️ **Push Notifications**: Requires separate APNs configuration for dev Bundle ID.

⚠️ **Code Signing**: Must complete Apple Developer setup before first dev build.

## Questions?

Check the detailed guide or Xcode build logs for specific errors.
