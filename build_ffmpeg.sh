#!/usr/bin/env bash

set -e

echo "=== Custom FFmpeg Local Compiler ==="

# Check environment or local.properties for NDK
NDK_PATH=""
if [ -n "$ANDROID_NDK_HOME" ] && [ -d "$ANDROID_NDK_HOME" ]; then
    NDK_PATH="$ANDROID_NDK_HOME"
elif [ -n "$ANDROID_NDK_ROOT" ] && [ -d "$ANDROID_NDK_ROOT" ]; then
    NDK_PATH="$ANDROID_NDK_ROOT"
elif [ -f "local.properties" ]; then
    NDK_PATH=$(grep -E 'ndk.dir|android.ndk' local.properties | cut -d'=' -f2 | xargs)
fi

if [ -z "$NDK_PATH" ] || [ ! -d "$NDK_PATH" ]; then
    echo "Error: Android NDK not found."
    echo "Please set ANDROID_NDK_HOME environment variable, or configure it in local.properties:"
    echo "  ndk.dir=/path/to/android-ndk"
    echo "Refer to local.properties.example for reference."
    exit 1
fi

echo "Found Android NDK at: $NDK_PATH"
ABI="arm64-v8a"
TARGET_DIR="app/src/main/jniLibs/$ABI"
mkdir -p "$TARGET_DIR"

if [ ! -d "ffmpeg-source" ]; then
    echo "Cloning official FFmpeg source code (branch n7.0.1)..."
    git clone --depth 1 --branch n7.0.1 https://github.com/FFmpeg/FFmpeg.git ffmpeg-source
fi

echo "Compiling FFmpeg..."
cd ffmpeg-source

TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
TARGET="aarch64-linux-android"
API="26"

CC="$TOOLCHAIN/bin/${TARGET}${API}-clang"
AS="$CC"
AR="$TOOLCHAIN/bin/llvm-ar"
RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
STRIP="$TOOLCHAIN/bin/llvm-strip"

./configure \
  --cross-prefix="$TOOLCHAIN/bin/$TARGET-" \
  --sysroot="$TOOLCHAIN/sysroot" \
  --target-os=android \
  --arch=aarch64 \
  --cpu=armv8-a \
  --cc="$CC" \
  --as="$AS" \
  --ar="$AR" \
  --ranlib="$RANLIB" \
  --strip="$STRIP" \
  --enable-cross-compile \
  --enable-static \
  --disable-shared \
  --disable-doc \
  --enable-ffmpeg \
  --disable-ffplay \
  --disable-ffprobe \
  --disable-symver \
  --enable-gpl \
  --enable-version3

make -j$(nproc)
$STRIP ffmpeg

cd ..
cp ffmpeg-source/ffmpeg "$TARGET_DIR/libffmpeg.so"
echo "Successfully compiled and placed libffmpeg.so in $TARGET_DIR/libffmpeg.so"
