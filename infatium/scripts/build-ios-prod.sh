#!/bin/bash
set -e

CONFIG_FILE="config/prod.local.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: $CONFIG_FILE not found!"
  echo "Run: ./scripts/setup.sh"
  exit 1
fi

echo "🚀 Building iOS Production (App Store)..."
echo "📁 Config: $CONFIG_FILE"
echo "📦 Bundle ID: com.nirssyan.makefeed"
echo "📱 Display Name: infatium"
echo ""

flutter build ipa \
  --release \
  --dart-define-from-file="$CONFIG_FILE" \
  --export-options-plist=ios/ExportOptionsProd.plist

echo ""
echo "✅ Production build complete!"
echo "📂 Output: build/ios/ipa/"
echo "⬆️  Upload to App Store (App Store Connect)"
