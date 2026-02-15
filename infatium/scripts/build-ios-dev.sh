#!/bin/bash
set -e

CONFIG_FILE="config/dev.local.json"
EXTRA_DEFINES=""

for arg in "$@"; do
  case "$arg" in
    --debug-logs)
      EXTRA_DEFINES="--dart-define=ENABLE_DEBUG_LOGGING=true"
      ;;
    --no-debug-logs)
      EXTRA_DEFINES="--dart-define=ENABLE_DEBUG_LOGGING=false"
      ;;
  esac
done

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: $CONFIG_FILE not found!"
  echo "Run: ./scripts/setup.sh"
  exit 1
fi

echo "🚀 Building iOS Dev (TestFlight)..."
echo "📁 Config: $CONFIG_FILE"
echo "📦 Bundle ID: com.nirssyan.makefeed.dev"
echo "📱 Display Name: порнахаб"
if [ "$EXTRA_DEFINES" = "--dart-define=ENABLE_DEBUG_LOGGING=false" ]; then
  echo "📋 Debug logging: DISABLED"
fi
echo ""

flutter build ipa \
  --flavor dev \
  --release \
  --dart-define-from-file="$CONFIG_FILE" \
  --export-options-plist=ios/ExportOptionsDev.plist \
  $EXTRA_DEFINES

echo ""
echo "✅ Dev build complete!"
echo "📂 Output: build/ios/ipa/"
echo "⬆️  Upload to TestFlight (App Store Connect)"
