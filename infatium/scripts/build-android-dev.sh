#!/bin/bash
set -e

CONFIG_FILE="config/dev.local.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: $CONFIG_FILE not found!"
  echo "Run: ./scripts/setup.sh"
  exit 1
fi

echo "🤖 Building Android APK (DEVELOPMENT)..."
echo "📁 Config: $CONFIG_FILE"
echo ""

flutter build apk --release --dart-define-from-file="$CONFIG_FILE"

echo ""
echo "✅ Android APK build complete!"
echo "📦 Location: build/app/outputs/flutter-apk/app-release.apk"
