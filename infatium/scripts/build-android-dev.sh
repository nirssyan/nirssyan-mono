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

echo "🤖 Building Android APK (DEVELOPMENT)..."
echo "📁 Config: $CONFIG_FILE"
if [ "$EXTRA_DEFINES" = "--dart-define=ENABLE_DEBUG_LOGGING=false" ]; then
  echo "📋 Debug logging: DISABLED"
fi
echo ""

flutter build apk --flavor dev --release --dart-define-from-file="$CONFIG_FILE" $EXTRA_DEFINES

echo ""
echo "✅ Android APK build complete!"
echo "📦 Location: build/app/outputs/flutter-apk/app-dev-release.apk"
