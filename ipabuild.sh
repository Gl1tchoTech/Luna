#!/bin/bash

set -e

cd "$(dirname "$0")"

WORKING_LOCATION="$(pwd)"
APPLICATION_NAME="Luna"

PLATFORM=${1:-ios}

case "$PLATFORM" in
    ios|iOS)
        PLATFORM="ios"
        SDK="iphoneos"
        XCODE_DESTINATION="generic/platform=iOS"
        PLATFORM_DIR="Release-iphoneos"
        OUTPUT_SUFFIX=""
        CODE_SIGN_IDENTITY=""
        CODE_SIGNING_ALLOWED="NO"
        XCODE_EXTRA_FLAGS=""
        ;;
    ios-sim|ios-simulator)
        PLATFORM="ios-sim"
        SDK="iphonesimulator"
        XCODE_DESTINATION="generic/platform=iOS Simulator"
        PLATFORM_DIR="Release-iphonesimulator"
        OUTPUT_SUFFIX=""
        CODE_SIGN_IDENTITY="-"
        CODE_SIGNING_ALLOWED="YES"
        XCODE_EXTRA_FLAGS="ONLY_ACTIVE_ARCH=NO"
        ;;
    tvos|tvOS)
        PLATFORM="tvos"
        SDK="appletvos"
        XCODE_DESTINATION="generic/platform=tvOS"
        PLATFORM_DIR="Release-appletvos"
        OUTPUT_SUFFIX="-tvOS"
        CODE_SIGN_IDENTITY=""
        CODE_SIGNING_ALLOWED="NO"
        XCODE_EXTRA_FLAGS=""
        ;;
    *)
        echo "Error: Invalid platform '$PLATFORM'"
        echo "Usage: $0 [ios|ios-sim|tvos]"
        echo "  ios     - Build for iOS device (IPA only)"
        echo "  ios-sim - Build for iOS Simulator for Appetize (.app.zip only)"
        echo "  tvos    - Build for tvOS device (IPA only)"
        exit 1
        ;;
esac

if [ ! -d "build" ]; then
    mkdir build
fi

cd build

if [ -d "DerivedData$PLATFORM" ]; then
    rm -rf "DerivedData$PLATFORM"
fi

xcodebuild -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration Release \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedData$PLATFORM" \
    -destination "$XCODE_DESTINATION" \
    -sdk "$SDK" \
    clean build \
    $XCODE_EXTRA_FLAGS \
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED"

DD_APP_PATH="$WORKING_LOCATION/build/DerivedData$PLATFORM/Build/Products/$PLATFORM_DIR/$APPLICATION_NAME.app"
TARGET_APP="$WORKING_LOCATION/build/$APPLICATION_NAME$OUTPUT_SUFFIX.app"

cp -r "$DD_APP_PATH" "$TARGET_APP"

if [ "$PLATFORM" = "ios-sim" ]; then
    # Simulator build: apply ad-hoc code signing (required for arm64 simulator on Apple Silicon)
    codesign --force --sign - "$TARGET_APP" 2>/dev/null || true
else
    # Device build: strip code signatures for IPA packaging
    codesign --remove "$TARGET_APP" 2>/dev/null || true
    if [ -e "$TARGET_APP/_CodeSignature" ]; then
        rm -rf "$TARGET_APP/_CodeSignature"
    fi
    if [ -e "$TARGET_APP/embedded.mobileprovision" ]; then
        rm -rf "$TARGET_APP/embedded.mobileprovision"
    fi
fi

# Create output artifacts
if [ "$PLATFORM" = "ios-sim" ]; then
    # Simulator build: only produce .app.zip for Appetize
    zip -qr "$APPLICATION_NAME.app.zip" "$APPLICATION_NAME.app"
    rm -rf "$TARGET_APP"
else
    # Device build: produce .ipa only (no .app.zip needed)
    mkdir Payload
    cp -r "$TARGET_APP" "Payload/$APPLICATION_NAME.app"

    if [ -f "Payload/$APPLICATION_NAME.app/$APPLICATION_NAME" ]; then
        strip "Payload/$APPLICATION_NAME.app/$APPLICATION_NAME" 2>/dev/null || true
    fi

    zip -qr "$APPLICATION_NAME$OUTPUT_SUFFIX.ipa" Payload

    rm -rf "$TARGET_APP"
    rm -rf Payload
fi
