#!/bin/bash

# Script to automatically update app icons from the latest infatiumv*.png file
# Usage: ./update_app_icons.sh

set -e  # Exit on error

echo "========================================="
echo "🎨 App Icons Update Script"
echo "========================================="
echo ""

# Find all infatiumv*.png files in newlogo directory
ICON_DIR="newlogo"
ICON_PATTERN="infatiumv*.png"

# Check if newlogo directory exists
if [ ! -d "$ICON_DIR" ]; then
    echo "❌ Error: Directory '$ICON_DIR' not found!"
    exit 1
fi

# Find all matching files and extract version numbers
echo "🔍 Searching for icon files in $ICON_DIR/..."
LATEST_VERSION=-1
LATEST_FILE=""

for file in $ICON_DIR/infatiumv*.png; do
    if [ -f "$file" ]; then
        # Extract version number (e.g., "infatiumv3.png" -> "3")
        VERSION=$(echo "$file" | sed 's/.*infatiumv\([0-9]*\)\.png/\1/')

        echo "   Found: $file (version $VERSION)"

        if [ "$VERSION" -gt "$LATEST_VERSION" ]; then
            LATEST_VERSION=$VERSION
            LATEST_FILE=$file
        fi
    fi
done

# Check if any file was found
if [ -z "$LATEST_FILE" ]; then
    echo ""
    echo "❌ Error: No infatiumv*.png files found in $ICON_DIR/"
    exit 1
fi

echo ""
echo "✅ Latest version found: v$LATEST_VERSION"
echo "📁 Source file: $LATEST_FILE"
echo ""

# Verify file is 1024x1024
FILE_SIZE=$(sips -g pixelWidth -g pixelHeight "$LATEST_FILE" | grep -E 'pixelWidth|pixelHeight' | awk '{print $2}' | paste -sd 'x' -)
echo "📐 Image size: $FILE_SIZE"

if [ "$FILE_SIZE" != "1024x1024" ]; then
    echo "⚠️  Warning: Image is not 1024x1024. Some icons may be scaled incorrectly."
fi

echo ""
echo "========================================="
echo "🍎 Generating iOS icons..."
echo "========================================="

IOS_ICON_DIR="ios/Runner/Assets.xcassets/AppIcon.appiconset"

# iOS icon sizes (in pixels)
IOS_SIZES=(20 29 40 50 57 58 60 72 76 80 87 100 114 120 144 152 167 180)

for size in "${IOS_SIZES[@]}"; do
    echo "  Generating ${size}x${size}..."
    sips -z $size $size "$LATEST_FILE" --out "$IOS_ICON_DIR/${size}.png" > /dev/null 2>&1
done

# Copy 1024x1024 directly (App Store icon)
echo "  Copying 1024x1024..."
cp "$LATEST_FILE" "$IOS_ICON_DIR/1024.png"

echo "✅ iOS icons generated (19 files)"
echo ""

echo "========================================="
echo "🤖 Generating Android icons..."
echo "========================================="

# Android icon sizes and directories (compatible with bash 3.2)
echo "  Generating mipmap-mdpi (48x48)..."
sips -z 48 48 "$LATEST_FILE" --out "android/app/src/main/res/mipmap-mdpi/ic_launcher.png" > /dev/null 2>&1

echo "  Generating mipmap-hdpi (72x72)..."
sips -z 72 72 "$LATEST_FILE" --out "android/app/src/main/res/mipmap-hdpi/ic_launcher.png" > /dev/null 2>&1

echo "  Generating mipmap-xhdpi (96x96)..."
sips -z 96 96 "$LATEST_FILE" --out "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png" > /dev/null 2>&1

echo "  Generating mipmap-xxhdpi (144x144)..."
sips -z 144 144 "$LATEST_FILE" --out "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png" > /dev/null 2>&1

echo "  Generating mipmap-xxxhdpi (192x192)..."
sips -z 192 192 "$LATEST_FILE" --out "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" > /dev/null 2>&1

echo "✅ Android icons generated (5 densities)"
echo ""

echo "========================================="
echo "🎉 Icons update complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  • Source: $LATEST_FILE (v$LATEST_VERSION)"
echo "  • iOS icons: 19 files"
echo "  • Android icons: 5 densities"
echo ""
echo "Next steps:"
echo "  1. Run 'flutter clean' to clear cache"
echo "  2. Rebuild your app with 'flutter run' or 'flutter build'"
echo ""
