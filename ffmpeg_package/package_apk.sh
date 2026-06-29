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

echo "Building release APK using Gradle..."
./gradlew :app:assembleRelease

APK="app/build/outputs/apk/release/app-release-unsigned.apk"

# Post-process APK to restore execute permission on native binaries.
# Gradle/AAPT2 strips them during packaging, but Android PackageManager
# preserves zip entry permissions on extraction.
echo "Fixing native binary permissions in APK..."
bash "$(dirname "$0")/../fix_apk_permissions.sh" "$APK" "ffmpeg"

echo ""
echo "=== Build Successful ==="
echo "Unsigned package APK generated at:"
echo "  $APK"
echo ""
echo "Instructions for signing:"
echo "1. Run apksigner to sign the APK:"
echo "   apksigner sign --ks <your-keystore-path> --ks-key-alias <your-alias> $APK"
echo "2. Find the SHA-256 fingerprint of the certificate used to sign the APK:"
echo "   apksigner verify --print-certs $APK | grep -i sha-256"
echo "3. Update the TRUSTED_RUNTIME_SIGNER_SHA256_DIGESTS constant in FfmpegUpdateManager.kt with this fingerprint."
