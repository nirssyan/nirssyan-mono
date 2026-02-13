# Configuration Guide

This directory contains environment configuration for the Makefeed Flutter app.

## Quick Start

**First time setup:**
```bash
# Run from project root
./scripts/setup.sh

# Edit config files with your API keys
nano config/dev.local.json
nano config/prod.local.json
```

**Run the app:**
```bash
./scripts/run-dev.sh              # Development environment
./scripts/run-prod.sh             # Production environment
./scripts/run-dev.sh -d chrome    # Run on specific device
```

## File Structure

```
config/
├── dev.json                    # Dev defaults (no secrets, committed)
├── prod.json                   # Prod defaults (no secrets, committed)
├── dev.local.json.example      # Dev template with real keys (committed)
├── prod.local.json.example     # Prod template with real keys (committed)
├── dev.local.json              # Your local dev config (gitignored)
├── prod.local.json             # Your local prod config (gitignored)
└── README.md                   # This file
```

## Configuration Files Explained

### `dev.json` / `prod.json`
- **Purpose**: Public URL defaults for each environment
- **Tracked in git**: YES ✅
- **Contains secrets**: NO ❌
- **Used by**: Scripts as base config

### `dev.local.json.example` / `prod.local.json.example`
- **Purpose**: Templates showing all required fields with real dev keys
- **Tracked in git**: YES ✅
- **Contains secrets**: YES (dev environment keys only)
- **Used by**: Developers to create their `*.local.json` files

### `dev.local.json` / `prod.local.json`
- **Purpose**: Your actual runtime configuration
- **Tracked in git**: NO ❌ (gitignored)
- **Contains secrets**: YES (your API keys)
- **Used by**: `flutter run` and `flutter build` commands

## Environment Variables

### Required (no defaults)

| Variable | Type | Description |
|----------|------|-------------|
| `API_KEY` | Secret | Backend API authentication key |
| `APPMETRICA_API_KEY` | Secret | Yandex AppMetrica analytics key |
| `GLITCHTIP_DSN` | Secret | GlitchTip error tracking DSN |

### Optional (have defaults)

| Variable | Default (Dev) | Default (Prod) | Description |
|----------|---------------|----------------|-------------|
| `API_BASE_URL` | `https://dev.api.infatium.ru` | `https://api.infatium.ru` | Backend API base URL |
| `CUSTOM_AUTH_BASE_URL` | `https://dev.api.infatium.ru/auth` | `https://api.infatium.ru/auth` | Auth service endpoint |
| `SHARE_BASE_URL` | `https://dev.infatium.ru` | `https://infatium.ru` | Base URL for shared news article links |
| `SPLASH_TEXT` | `infatium` | `infatium` | Splash screen text |
| `ENABLE_NOTIFICATIONS` | `true` | `true` | Enable push notifications |
| `ENABLE_DEBUG_LOGGING` | `true` | `false` | Enable debug logging to /debug/echo (works in release builds) |

## Getting API Keys

### API_KEY (Backend)
1. Contact backend team or check project documentation
2. Dev key is included in examples for convenience
3. Prod key should be kept secret

### APPMETRICA_API_KEY (Analytics)
1. Visit https://appmetrica.yandex.com/
2. Go to Application Settings → API Key
3. Copy the API key (UUID format)

### GLITCHTIP_DSN (Error Tracking)
1. Visit https://glitchtip.infra.makekod.ru
2. Select your project
3. Go to Settings → Client Keys (DSN)
4. Copy the DSN URL (format: `https://[key]@glitchtip.infra.makekod.ru/[project]`)
5. Production project (ID: 1): `https://f3a86334caf4467da51f2f4d60ae7186@glitchtip.infra.makekod.ru/1`

## Usage Examples

### Local Development
```bash
# Use dev environment (default)
./scripts/run-dev.sh

# Run on specific device
./scripts/run-dev.sh -d macos
./scripts/run-dev.sh -d chrome
./scripts/run-dev.sh -d <device-id>
```

### Production Testing
```bash
# Run with production backend
./scripts/run-prod.sh

# Build production releases
./scripts/build-ios-prod.sh
./scripts/build-android-prod.sh
```

### Custom Configuration
```bash
# Create custom config file
cp config/dev.local.json.example config/staging.local.json

# Edit with staging settings
nano config/staging.local.json

# Run with custom config
flutter run --dart-define-from-file=config/staging.local.json
```

### VS Code Integration
Press `Cmd+Shift+B` (macOS) or `Ctrl+Shift+B` (Windows/Linux):
- Select **"Run Dev"** for development environment
- Select **"Run Prod"** for production environment

## How It Works

### Old Workflow (15+ flags)
```bash
flutter run \
  --dart-define=API_KEY=xxx \
  --dart-define=APPMETRICA_API_KEY=yyy \
  --dart-define=API_BASE_URL=https://dev.api.infatium.ru \
  --dart-define=CUSTOM_AUTH_BASE_URL=https://dev.api.infatium.ru/auth \
  --dart-define=SPLASH_TEXT=infatium \
  --dart-define=ENABLE_NOTIFICATIONS=true
  # ... 9 more obsolete flags
```

### New Workflow (1 flag)
```bash
flutter run --dart-define-from-file=config/dev.local.json
```

The `--dart-define-from-file` flag (available since Flutter 3.7+) loads all variables from a JSON file, replacing manual `--dart-define` flags.

## Security Notes

### What's Safe to Commit

✅ **SAFE**:
- `dev.json`, `prod.json` (public URLs only)
- `dev.local.json.example`, `prod.local.json.example` (dev keys for convenience)
- This README

❌ **NEVER COMMIT**:
- `dev.local.json`, `prod.local.json` (your actual secrets)
- Production API keys in any file

### Project Policy on Secrets

This project intentionally includes **dev environment keys** in committed files for:
- Faster developer onboarding
- Better AI-assisted development (Claude Code can help with config)
- Simplified local development

**Production keys** should NEVER be committed and must be:
- Stored in gitignored `*.local.json` files
- Injected via CI/CD secrets (GitHub Actions)
- Rotated immediately if exposed

## Troubleshooting

### Error: "config/dev.local.json not found"
```bash
# Solution: Run setup script
./scripts/setup.sh

# Or manually copy
cp config/dev.local.json.example config/dev.local.json
```

### Error: "API_KEY is required"
```bash
# Solution: Edit config file with your API key
nano config/dev.local.json

# Make sure API_KEY and APPMETRICA_API_KEY are set
```

### Script permission denied
```bash
# Solution: Make scripts executable
chmod +x scripts/*.sh
```

### VS Code tasks not showing
```bash
# Solution: Reload VS Code window
# Press Cmd+Shift+P → "Developer: Reload Window"
```

## Migration from Old System

If you were using the old `--dart-define` workflow:

1. **Backup your keys** (from `run-command.txt` or shell history)
2. **Run setup**: `./scripts/setup.sh`
3. **Copy your keys** to `config/dev.local.json`
4. **Test**: `./scripts/run-dev.sh`
5. **Delete old files**: Old run-command.txt already removed ✅

Old workflow still works if needed:
```bash
flutter run --dart-define=API_KEY=xxx --dart-define=APPMETRICA_API_KEY=yyy ...
```

## CI/CD Integration

GitHub Actions workflows automatically create production config:

```yaml
- name: Create production config
  run: |
    mkdir -p config
    cat > config/prod.local.json <<EOF
    {
      "API_KEY": "${{ secrets.API_KEY }}",
      "APPMETRICA_API_KEY": "${{ secrets.APPMETRICA_API_KEY }}",
      ...
    }
    EOF

- name: Build
  run: flutter build apk --dart-define-from-file=config/prod.local.json
```

Secrets are stored in GitHub repository settings, not in code.

## Support

- Documentation: See `CLAUDE.md` in project root
- Issues: GitHub Issues
- Questions: Ask in project Discord/Slack
