#!/bin/bash
# Build BearMinder for distribution

set -e  # Exit on error

echo "🏗️  Building BearMinder for release..."

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/Apps/BearMinder"
BUILD_DIR="$PROJECT_DIR/build-release"
ARCHIVE_NAME="BearMinder.zip"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Generate Xcode project if needed
echo "📦 Generating Xcode project..."
cd "$APP_DIR"
if [ ! -f "BearMinder.xcodeproj/project.pbxproj" ]; then
    xcodegen generate
fi

# Build the app
echo "🔨 Building app..."
xcodebuild \
    -project BearMinder.xcodeproj \
    -scheme BearMinder \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/derived" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    clean build

# Copy app to build directory
APP_PATH="$BUILD_DIR/derived/Build/Products/Release/BearMinder.app"
RELEASE_PATH="$BUILD_DIR/BearMinder.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed - app not found at $APP_PATH"
    exit 1
fi

echo "📋 Copying app to release directory..."
cp -R "$APP_PATH" "$RELEASE_PATH"

# Remove any extended attributes that might cause issues
echo "🧽 Cleaning extended attributes..."
xattr -cr "$RELEASE_PATH"

# Create zip archive
echo "📦 Creating zip archive..."
cd "$BUILD_DIR"
zip -r "$ARCHIVE_NAME" BearMinder.app

# Show results
echo ""
echo "✅ Build complete!"
echo ""
echo "📍 Release files:"
echo "   App:     $RELEASE_PATH"
echo "   Archive: $BUILD_DIR/$ARCHIVE_NAME"
echo ""
echo "🚀 To create a GitHub release:"
echo "   1. Go to: https://github.com/brennanbrown/bearminder/releases/new"
echo "   2. Tag version (e.g., v0.1.0-beta.1)"
echo "   3. Upload: $BUILD_DIR/$ARCHIVE_NAME"
echo "   4. Mark as pre-release"
echo ""
