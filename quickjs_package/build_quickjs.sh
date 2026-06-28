#!/usr/bin/env bash

set -e

echo "=== Custom QuickJS Android Compiler ==="

# Check environment or local.properties for NDK
NDK_PATH=""
if [ -n "$ANDROID_NDK_HOME" ] && [ -d "$ANDROID_NDK_HOME" ]; then
    NDK_PATH="$ANDROID_NDK_HOME"
elif [ -n "$ANDROID_NDK_ROOT" ] && [ -d "$ANDROID_NDK_ROOT" ]; then
    NDK_PATH="$ANDROID_NDK_ROOT"
elif [ -f "local.properties" ]; then
    NDK_PATH=$(grep -E 'ndk.dir|android.ndk' local.properties | cut -d'=' -f2 | xargs)
elif [ -f "../ffmpeg_package/local.properties" ]; then
    NDK_PATH=$(grep -E 'ndk.dir|android.ndk' ../ffmpeg_package/local.properties | cut -d'=' -f2 | xargs)
fi

if [ -z "$NDK_PATH" ] || [ ! -d "$NDK_PATH" ]; then
    echo "Error: Android NDK not found."
    echo "Please set ANDROID_NDK_HOME environment variable, or configure it in local.properties:"
    echo "  ndk.dir=/path/to/android-ndk"
    exit 1
fi

echo "Found Android NDK at: $NDK_PATH"
ABI="arm64-v8a"

export TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
export TARGET="aarch64-linux-android"
export API="26"

export CC="$TOOLCHAIN/bin/$TARGET$API-clang"
export CXX="$TOOLCHAIN/bin/$TARGET$API-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"

# 1. Download QuickJS source code
if [ ! -d "quickjs-source" ]; then
    echo "Downloading QuickJS 2024-01-13 source..."
    wget -q https://bellard.org/quickjs/quickjs-2024-01-13.tar.xz
    tar -xf quickjs-2024-01-13.tar.xz
    mv quickjs-2024-01-13 quickjs-source
    rm -f quickjs-2024-01-13.tar.xz
fi

# 2. Cross-Compile QuickJS shared library for Android
echo "Compiling QuickJS into libqjs.so..."
cd quickjs-source

# Compile object files and link into libqjs.so
$CC -O3 -fPIC -shared -o libqjs.so \
  quickjs.c \
  quickjs-libc.c \
  libregexp.c \
  libunicode.c \
  cutils.c \
  -DCONFIG_VERSION=\"2024-01-13\" \
  -lm -ldl

$STRIP libqjs.so
cd ..

# 3. Copy target output binary to Gradle project
TARGET_JNI_DIR="app/src/main/jniLibs/$ABI"
mkdir -p "$TARGET_JNI_DIR"
echo "Copying libqjs.so to JNI directory..."
cp quickjs-source/libqjs.so "$TARGET_JNI_DIR/libqjs.so"

echo "=== QuickJS Compilation Completed Successfully ==="
echo "Packaged JNI file outputted to: $TARGET_JNI_DIR/libqjs.so"
