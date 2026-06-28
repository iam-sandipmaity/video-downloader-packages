#!/usr/bin/env bash

set -e

echo "=== Packaging Custom QuickJS APK ==="

# Check if target binary exists
ABI="arm64-v8a"
BINARY_SO="app/src/main/jniLibs/$ABI/libqjs.so"

if [ ! -f "$BINARY_SO" ]; then
    echo "Error: libqjs.so not found under app/src/main/jniLibs/$ABI/"
    echo "Please compile QuickJS using ./build_quickjs.sh first."
    exit 1
fi

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
echo "3. Update the TRUSTED_RUNTIME_SIGNER_SHA256_DIGESTS constant in the updater with this fingerprint."
