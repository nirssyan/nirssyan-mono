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

echo "🤖 Building Android APK (PRODUCTION)..."
echo "📁 Config: $CONFIG_FILE"
if [ -n "$EXTRA_DEFINES" ]; then
  echo "📋 Debug logging: ENABLED"
fi
echo ""

flutter build apk --flavor prod --release --dart-define-from-file="$CONFIG_FILE" $EXTRA_DEFINES

echo ""
echo "✅ Android APK build complete!"
echo "📦 Location: build/app/outputs/flutter-apk/app-prod-release.apk"
