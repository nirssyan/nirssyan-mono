#!/bin/bash
set -e

CONFIG_FILE="config/dev.local.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: $CONFIG_FILE not found!"
  echo ""
  echo "Run setup first:"
  echo "  ./scripts/setup.sh"
  echo ""
  echo "Or manually create:"
  echo "  cp config/dev.local.json.example config/dev.local.json"
  echo "  nano config/dev.local.json"
  exit 1
fi

echo "🚀 Running Makefeed in DEVELOPMENT mode..."
echo "📁 Config: $CONFIG_FILE"
echo ""

flutter run --dart-define-from-file="$CONFIG_FILE" "$@"
