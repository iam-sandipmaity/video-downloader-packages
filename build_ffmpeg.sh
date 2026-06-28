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

# Check and compile mbedtls locally if not present
MBEDTLS_DIR="$(pwd)/mbedtls_install"
if [ ! -d "mbedtls-source" ]; then
    echo "Cloning mbedtls..."
    git clone --depth 1 --branch v3.6.0 https://github.com/Mbed-TLS/mbedtls.git mbedtls-source
    cd mbedtls-source
    git submodule update --init --recursive
    cd ..
fi

if [ ! -d "$MBEDTLS_DIR" ]; then
    echo "Compiling mbedtls..."
    mkdir -p mbedtls-source/build
    cd mbedtls-source/build
    cmake -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI="arm64-v8a" \
      -DANDROID_PLATFORM="android-26" \
      -DENABLE_PROGRAMS=OFF \
      -DENABLE_TESTING=OFF \
      -DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
      -DUSE_STATIC_MBEDTLS_LIBRARY=ON \
      -DCMAKE_INSTALL_PREFIX="$MBEDTLS_DIR" \
      ..
    make -j$(nproc)
    make install
    cd ../..
fi

# Check and compile x264 locally if not present
X264_DIR="$(pwd)/x264_install"
if [ ! -d "x264-source" ]; then
    echo "Cloning x264..."
    git clone --depth 1 https://code.videolan.org/videolan/x264.git x264-source
fi

if [ ! -d "$X264_DIR" ]; then
    echo "Compiling x264..."
    cd x264-source
    
    TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
    TARGET="aarch64-linux-android"
    API="26"
    
    CC="$TOOLCHAIN/bin/$TARGET$API-clang"
    AR="$TOOLCHAIN/bin/llvm-ar"
    RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
    NM="$TOOLCHAIN/bin/llvm-nm"
    STRIP="$TOOLCHAIN/bin/llvm-strip"
    export STRINGS="$TOOLCHAIN/bin/llvm-strings"
    export OBJDUMP="$TOOLCHAIN/bin/llvm-objdump"
    
    ./configure \
      --cross-prefix="$TOOLCHAIN/bin/$TARGET-" \
      --sysroot="$TOOLCHAIN/sysroot" \
      --host=aarch64-linux-android \
      --enable-static \
      --disable-cli \
      --enable-pic \
      --prefix="$X264_DIR"
      
    make -j$(nproc)
    make install
    cd ..
fi

# Check and compile libmp3lame locally if not present
LAME_DIR="$(pwd)/lame_install"
if [ ! -d "lame-3.100" ]; then
    echo "Downloading and extracting lame..."
    wget https://deb.debian.org/debian/pool/main/l/lame/lame_3.100.orig.tar.gz
    tar -xzf lame_3.100.orig.tar.gz
    cd lame-3.100
    find . -type f -exec sed -i 's/ieee754_float32_t/float/g' {} +
    cd ..
fi

if [ ! -d "$LAME_DIR" ]; then
    echo "Compiling lame..."
    cd lame-3.100
    
    TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
    TARGET="aarch64-linux-android"
    API="26"
    
    CC="$TOOLCHAIN/bin/$TARGET$API-clang"
    AR="$TOOLCHAIN/bin/llvm-ar"
    RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
    
    ./configure \
      --host=aarch64-linux-android \
      --enable-static \
      --disable-shared \
      --disable-frontend \
      --prefix="$LAME_DIR" \
      CC="$CC --sysroot=$TOOLCHAIN/sysroot" \
      AR="$AR" \
      RANLIB="$RANLIB"
      
    make -j$(nproc)
    make install
    cd ..
fi

if [ ! -d "ffmpeg-source" ]; then
    echo "Cloning official FFmpeg source code (branch n7.1.1)..."
    git clone --depth 1 --branch n7.1.1 https://github.com/FFmpeg/FFmpeg.git ffmpeg-source
fi

echo "Compiling FFmpeg..."

# Create pkgconfig files for local build
mkdir -p pkgconfig
cat << EOF > pkgconfig/mbedtls.pc
prefix=$MBEDTLS_DIR
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: mbedtls
Description: mbed TLS light-weight SSL/TLS library
Version: 3.6.0
Libs: -L\${libdir} -lmbedtls -lmbedx509 -lmbedcrypto
Cflags: -I\${includedir}
EOF

cat << EOF > pkgconfig/mbedx509.pc
prefix=$MBEDTLS_DIR
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: mbedx509
Description: mbed TLS x509 library
Version: 3.6.0
Libs: -L\${libdir} -lmbedx509
Cflags: -I\${includedir}
EOF

cat << EOF > pkgconfig/mbedcrypto.pc
prefix=$MBEDTLS_DIR
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: mbedcrypto
Description: mbed TLS crypto library
Version: 3.6.0
Libs: -L\${libdir} -lmbedcrypto
Cflags: -I\${includedir}
EOF

export PKG_CONFIG_PATH="$X264_DIR/lib/pkgconfig:$(pwd)/pkgconfig"

cd ffmpeg-source

TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
TARGET="aarch64-linux-android"
API="26"

CC="$TOOLCHAIN/bin/${TARGET}${API}-clang"
AS="$CC"
AR="$TOOLCHAIN/bin/llvm-ar"
NM="$TOOLCHAIN/bin/llvm-nm"
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
  --nm="$NM" \
  --ranlib="$RANLIB" \
  --strip="$STRIP" \
  --enable-cross-compile \
  --pkg-config="pkg-config" \
  --pkg-config-flags="--static" \
  --enable-static \
  --disable-shared \
  --disable-doc \
  --enable-ffmpeg \
  --disable-ffplay \
  --disable-ffprobe \
  --disable-symver \
  --enable-gpl \
  --enable-version3 \
  --disable-everything \
  --enable-mbedtls \
  --enable-libx264 \
  --enable-libmp3lame \
  --enable-protocol=file,http,https,tcp,udp,tls \
  --enable-demuxer=mov,matroska,hls,aac,mp3,ogg,flac,wav \
  --enable-muxer=mp4,mov,matroska,webm,aac,mp3,ogg,opus,flac,wav,image2 \
  --enable-decoder=h264,hevc,vp9,av1,aac,opus,mp3,flac,vorbis,png,mjpeg \
  --enable-encoder=libx264,libmp3lame,aac,opus,flac \
  --enable-parser=h264,hevc,vp9,av1,aac,opus,mpegaudio,png,mjpeg \
  --enable-filter=aformat,aresample,scale,crop,null,trim,atrim \
  --enable-asm \
  --enable-neon \
  --enable-lto \
  --extra-cflags="-I$MBEDTLS_DIR/include -I$X264_DIR/include -I$LAME_DIR/include" \
  --extra-ldflags="-L$MBEDTLS_DIR/lib -L$X264_DIR/lib -L$LAME_DIR/lib"

make -j$(nproc)
$STRIP ffmpeg

cd ..
cp ffmpeg-source/ffmpeg "$TARGET_DIR/libffmpeg.so"
echo "Successfully compiled and placed libffmpeg.so in $TARGET_DIR/libffmpeg.so"
