#!/bin/bash
set -e

CONFIG_FILE="config/prod.local.json"
EXTRA_DEFINES=""

for arg in "$@"; do
  case "$arg" in
    --debug-logs)
      EXTRA_DEFINES="--dart-define=ENABLE_DEBUG_LOGGING=true"
      ;;
  esac
done

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: $CONFIG_FILE not found!"
  echo "Run: ./scripts/setup.sh"
  exit 1
fi

echo "🚀 Building iOS Production (App Store)..."
echo "📁 Config: $CONFIG_FILE"
echo "📦 Bundle ID: com.nirssyan.makefeed"
echo "📱 Display Name: infatium"
if [ -n "$EXTRA_DEFINES" ]; then
  echo "📋 Debug logging: ENABLED"
fi
echo ""

flutter build ipa \
  --flavor prod \
  --release \
  --dart-define-from-file="$CONFIG_FILE" \
  --export-options-plist=ios/ExportOptionsProd.plist \
  $EXTRA_DEFINES

echo ""
echo "✅ Production build complete!"
echo "📂 Output: build/ios/ipa/"
echo "⬆️  Upload to App Store (App Store Connect)"
