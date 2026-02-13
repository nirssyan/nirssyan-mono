#!/bin/bash
set -e

echo "🛠️  Makefeed Development Setup"
echo ""

# Create dev.local.json if it doesn't exist
if [ ! -f "config/dev.local.json" ]; then
  cp config/dev.local.json.example config/dev.local.json
  echo "✅ Created config/dev.local.json (with dev API keys)"
else
  echo "⚠️  config/dev.local.json already exists (skipping)"
fi

# Create prod.local.json if it doesn't exist
if [ ! -f "config/prod.local.json" ]; then
  cp config/prod.local.json.example config/prod.local.json
  echo "✅ Created config/prod.local.json (with dev API keys)"
else
  echo "⚠️  config/prod.local.json already exists (skipping)"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit config files if needed (default keys should work for dev):"
echo "     nano config/dev.local.json"
echo "     nano config/prod.local.json"
echo ""
echo "  2. Run the app:"
echo "     ./scripts/run-dev.sh"
echo ""
echo "  3. Or use VS Code:"
echo "     Press Cmd+Shift+B → Select 'Run Dev'"
echo ""
