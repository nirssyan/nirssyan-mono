#!/bin/bash
set -e

CONFIG_FILE="config/dev.local.json"
EXTRA_DEFINES=""
PASSTHROUGH_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --no-debug-logs)
      EXTRA_DEFINES="--dart-define=ENABLE_DEBUG_LOGGING=false"
      ;;
    *)
      PASSTHROUGH_ARGS+=("$arg")
      ;;
  esac
done

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
if [ -n "$EXTRA_DEFINES" ]; then
  echo "📋 Debug logging: DISABLED"
fi
echo ""

flutter run --flavor dev --dart-define-from-file="$CONFIG_FILE" $EXTRA_DEFINES "${PASSTHROUGH_ARGS[@]}"
