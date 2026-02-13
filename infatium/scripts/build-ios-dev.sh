#!/bin/bash
set -e

CONFIG_FILE="config/dev.local.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: $CONFIG_FILE not found!"
  echo "Run: ./scripts/setup.sh"
  exit 1
fi

echo "🚀 Building iOS Dev (TestFlight)..."
echo "📁 Config: $CONFIG_FILE"
echo "📦 Bundle ID: com.nirssyan.makefeed.dev"
echo "📱 Display Name: infatium DEV"
echo ""

flutter build ipa \
  --release \
  --dart-define-from-file="$CONFIG_FILE" \
  --export-options-plist=ios/ExportOptionsDev.plist

echo ""
echo "✅ Dev build complete!"
echo "📂 Output: build/ios/ipa/"
echo "⬆️  Upload to TestFlight (App Store Connect)"
