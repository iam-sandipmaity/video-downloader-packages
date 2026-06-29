#!/usr/bin/env bash

set -e

echo "=== Packaging Custom FFmpeg APK ==="

# Check if target binary exists
ABI="arm64-v8a"
BINARY="app/src/main/jniLibs/$ABI/libffmpeg.so"

if [ ! -f "$BINARY" ]; then
    echo "Error: libffmpeg.so not found at $BINARY"
    echo "Please run ./build_ffmpeg.sh first to fetch or build the binary."
    exit 1
fi

# Ensure native binary has execute permission before packaging
# (Android PackageManager preserves zip entry permissions on extraction)
echo "Setting execute permission on native binary..."
chmod -v 755 app/src/main/jniLibs/$ABI/libffmpeg.so

echo "Building release APK using Gradle..."
./gradlew :app:assembleRelease

echo ""
echo "=== Build Successful ==="
echo "Unsigned package APK generated at:"
echo "  app/build/outputs/apk/release/app-release-unsigned.apk"
echo ""
echo "Instructions for signing:"
echo "1. Run apksigner to sign the APK:"
echo "   apksigner sign --ks <your-keystore-path> --ks-key-alias <your-alias> app/build/outputs/apk/release/app-release-unsigned.apk"
echo "2. Find the SHA-256 fingerprint of the certificate used to sign the APK:"
echo "   apksigner verify --print-certs app/build/outputs/apk/release/app-release-unsigned.apk | grep -i sha-256"
echo "3. Update the TRUSTED_RUNTIME_SIGNER_SHA256_DIGESTS constant in FfmpegUpdateManager.kt with this fingerprint."
