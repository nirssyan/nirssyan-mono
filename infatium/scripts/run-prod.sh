#!/bin/bash
set -e

CONFIG_FILE="config/prod.local.json"
EXTRA_DEFINES=""
PASSTHROUGH_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --debug-logs)
      EXTRA_DEFINES="--dart-define=ENABLE_DEBUG_LOGGING=true"
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
  echo "  cp config/prod.local.json.example config/prod.local.json"
  echo "  nano config/prod.local.json"
  exit 1
fi

echo "🚀 Running Makefeed in PRODUCTION mode..."
echo "📁 Config: $CONFIG_FILE"
if [ -n "$EXTRA_DEFINES" ]; then
  echo "📋 Debug logging: ENABLED"
fi
echo ""

flutter run --flavor prod --dart-define-from-file="$CONFIG_FILE" $EXTRA_DEFINES "${PASSTHROUGH_ARGS[@]}"
