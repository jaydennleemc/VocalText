#!/bin/bash

# VocalText Build and Test Script
# Used to test the build process locally and verify fixes

echo "=== VocalText Local Build and Test Script ==="

# Check if Xcode is installed
echo "Checking Xcode installation..."
if ! command -v xcodebuild &> /dev/null
then
    echo "❌ xcodebuild command not found"
    echo "Please ensure Xcode is installed and the license agreement is accepted"
    echo "You can resolve this by:"
    echo "1. Installing Xcode from the App Store"
    echo "2. Running: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo "3. Running: sudo xcodebuild -license"
    exit 1
fi

# Check if Xcode is properly set up
XCODE_PATH=$(xcode-select -p)
echo "Current Xcode path: $XCODE_PATH"

if [[ $XCODE_PATH == *CommandLineTools* ]]; then
    echo "❌ Currently using command line tools instead of full Xcode"
    echo "Please switch to full Xcode by running:"
    echo "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo "(If Xcode is installed in a different location, adjust the path accordingly)"
    exit 1
fi

echo "Starting to clean previous builds..."
# Clean previous builds
rm -rf .build DerivedData

echo "Building project..."
# Run build command (same steps as in GitHub workflow)
xcodebuild -project VocalText.xcodeproj \
  -scheme VocalText \
  -configuration Release \
  ONLY_ACTIVE_ARCH=NO 
  

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "❌ Build failed! Please check the error messages."
    exit 1
fi

echo "✅ Build successful!"

echo "Creating build artifacts..."
# Create build artifacts directory
mkdir -p .build

# Use the correct path to copy the app to the build artifacts directory
# Based on Xcode's output, the actual path is under Library/Developer/Xcode/DerivedData
XCODE_DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"
APP_NAME="VocalText"
APP_PATH=$(find "$XCODE_DERIVED_DATA_PATH" -name "$APP_NAME.app" -type d -path "*/Build/Products/Release/*" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Built app not found"
    exit 1
fi

# Copy app to build artifacts directory
cp -R "$APP_PATH" .build/

# Check if copy was successful
if [ ! -d ".build/VocalText.app" ]; then
    echo "❌ Failed to successfully copy the app"
    exit 1
fi

# Get version number
APP_VERSION=$(defaults read ".build/VocalText.app/Contents/Info.plist" CFBundleShortVersionString)

# If version number is empty, use default value
if [ -z "$APP_VERSION" ]; then
    APP_VERSION="1.0"
fi
echo "App version: $APP_VERSION"

# Create ZIP package
cd .build
zip -r "VocalText-${APP_VERSION}.zip" "VocalText.app"

echo "✅ Build artifact created: .build/VocalText-${APP_VERSION}.zip"

echo "=== Build completed ==="
echo "Next steps:"
echo "1. Extract the generated ZIP file"
echo "2. Run the app and test the microphone permission flow"
echo "3. Confirm if the fixes are effective"
echo ""
echo "Fixes include:"
echo "- Fixed duplicate permission request issue in checkMicrophonePermission method in MainView.swift"
echo "- Fixed duplicate permission request issue in requestMicrophonePermission method in MainView.swift"
echo "- Fixed the issue of duplicate MainView creation in MenuBarController.swift"
echo "- Added permission status checking to avoid repeatedly popping up permission dialogs"
echo "- Optimized permission checking logic to only pop up permission dialogs on first request"