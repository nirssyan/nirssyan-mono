#!/bin/bash
set -e

CONFIG_FILE="config/prod.local.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: $CONFIG_FILE not found!"
  echo ""
  echo "Run setup first:"
  echo "  ./scripts/setup.sh"
  echo ""
  echo "Or manually create:"
  echo "  cp config/prod.local.json.example config/prod.local.json"
  echo "  nano config/prod.local.json"
  exit 1
fi

echo "🚀 Running Makefeed in PRODUCTION mode..."
echo "📁 Config: $CONFIG_FILE"
echo ""

flutter run --dart-define-from-file="$CONFIG_FILE" "$@"
