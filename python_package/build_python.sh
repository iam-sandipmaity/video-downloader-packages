#!/usr/bin/env bash

set -e

echo "=== Custom Python Android Compiler ==="

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
export PREFIX_DIR="$(pwd)/python_install"
mkdir -p "$PREFIX_DIR"

export TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
export TARGET="aarch64-linux-android"
export API="26"

export CC="$TOOLCHAIN/bin/$TARGET$API-clang"
export CXX="$TOOLCHAIN/bin/$TARGET$API-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export READELF="$TOOLCHAIN/bin/llvm-readelf"

# 1. Compile zlib statically
if [ ! -d "zlib-source" ]; then
    echo "Downloading zlib..."
    wget -q https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
    tar -xzf zlib-1.3.1.tar.gz
    mv zlib-1.3.1 zlib-source
    rm -f zlib-1.3.1.tar.gz
fi

if [ ! -f "$PREFIX_DIR/lib/libz.a" ]; then
    echo "Compiling static zlib..."
    cd zlib-source
    CC="$CC" AR="$AR" RANLIB="$RANLIB" ./configure --static --prefix="$PREFIX_DIR"
    make -j$(nproc)
    make install
    cd ..
fi

# 2. Compile libffi statically
if [ ! -d "libffi-source" ]; then
    echo "Downloading libffi..."
    wget -q https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz
    tar -xzf libffi-3.4.6.tar.gz
    mv libffi-3.4.6 libffi-source
    rm -f libffi-3.4.6.tar.gz
fi

if [ ! -f "$PREFIX_DIR/lib/libffi.a" ]; then
    echo "Compiling static libffi..."
    cd libffi-source
    ./configure \
      --host=aarch64-linux-android \
      --enable-static \
      --disable-shared \
      --prefix="$PREFIX_DIR" \
      CC="$CC" \
      AR="$AR" \
      RANLIB="$RANLIB"
    make -j$(nproc)
    make install
    cd ..
fi

# 3. Compile OpenSSL statically
if [ ! -d "openssl-source" ]; then
    echo "Downloading OpenSSL..."
    wget -q https://www.openssl.org/source/old/3.3/openssl-3.3.1.tar.gz
    tar -xzf openssl-3.3.1.tar.gz
    mv openssl-3.3.1 openssl-source
    rm -f openssl-3.3.1.tar.gz
fi

if [ ! -f "$PREFIX_DIR/lib/libssl.a" ]; then
    echo "Compiling static OpenSSL..."
    cd openssl-source
    
    # Backup PATH and set target environment for OpenSSL
    ORIG_PATH="$PATH"
    export ANDROID_NDK_ROOT="$NDK_PATH"
    export PATH="$TOOLCHAIN/bin:$PATH"
    
    ./Configure android-arm64 no-shared no-tests --prefix="$PREFIX_DIR"
    make -j$(nproc)
    make install_sw
    
    # Restore original PATH
    export PATH="$ORIG_PATH"
    cd ..
fi

# 4. Download Python 3.11.9 source code
if [ ! -d "python-source" ]; then
    echo "Downloading CPython 3.11.9 source..."
    wget -q https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tar.xz
    tar -xf Python-3.11.9.tar.xz
    mv Python-3.11.9 python-source
    rm -f Python-3.11.9.tar.xz
fi

# 5. Build Host Python (runs on compilation host to generate target scripts/bytecode)
if [ ! -f "python-host/install/bin/python3" ]; then
    echo "Building native Host Python..."
    mkdir -p python-host
    cp -R python-source/* python-host/ || true
    
    # Save the target compiler variables to prevent host build pollution
    OLD_CC="$CC"
    OLD_CXX="$CXX"
    OLD_AR="$AR"
    OLD_RANLIB="$RANLIB"
    OLD_STRIP="$STRIP"
    OLD_READELF="$READELF"
    OLD_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
    OLD_PKG_CONFIG="$PKG_CONFIG"
    OLD_CPPFLAGS="$CPPFLAGS"
    OLD_LDFLAGS="$LDFLAGS"
    OLD_LIBS="$LIBS"
    
    # Unset them so host python configure detects the host gcc/clang and native headers
    unset CC CXX AR RANLIB STRIP READELF PKG_CONFIG_PATH PKG_CONFIG CPPFLAGS LDFLAGS LIBS
    
    cd python-host
    ./configure --prefix="$(pwd)/install"
    make -j$(nproc)
    make install
    cd ..
    
    # Restore the target compiler variables
    export CC="$OLD_CC"
    export CXX="$OLD_CXX"
    export AR="$OLD_AR"
    export RANLIB="$OLD_RANLIB"
    export STRIP="$OLD_STRIP"
    export READELF="$OLD_READELF"
    export PKG_CONFIG_PATH="$OLD_PKG_CONFIG_PATH"
    export PKG_CONFIG="$OLD_PKG_CONFIG"
    export CPPFLAGS="$OLD_CPPFLAGS"
    export LDFLAGS="$OLD_LDFLAGS"
    export LIBS="$OLD_LIBS"
fi

# 6. Cross-Compile Target Python for Android arm64-v8a
if [ ! -f "$PREFIX_DIR/lib/libpython3.11.so" ]; then
    echo "Cross-compiling Target Python for Android..."
    mkdir -p python-target
    cp -R python-source/* python-target/ || true
    cd python-target
    
    export PKG_CONFIG_PATH="$PREFIX_DIR/lib/pkgconfig"
    export PKG_CONFIG="pkg-config"
    export CPPFLAGS="-I$PREFIX_DIR/include"
    export LDFLAGS="-L$PREFIX_DIR/lib"
    export LIBS="-lssl -lcrypto -lffi -lz"
    
    ./configure \
      --host=aarch64-linux-android \
      --build=x86_64-pc-linux-gnu \
      --enable-shared \
      --with-build-python="$(pwd)/../python-host/install/bin/python3" \
      --prefix="$PREFIX_DIR/python_usr" \
      ac_cv_file__dev_ptmx=no \
      ac_cv_file__dev_ptc=no \
      ac_cv_have_long_double_format=mixed \
      ac_cv_header_uuid_h=no \
      ac_cv_header_crypt_h=no \
      ac_cv_lib_crypt_crypt=no \
      ac_cv_buggy_getaddrinfo=no \
      CC="$CC" \
      AR="$AR" \
      RANLIB="$RANLIB" \
      STRIP="$STRIP" \
      READELF="$READELF" \
      CPPFLAGS="$CPPFLAGS" \
      LDFLAGS="$LDFLAGS" \
      LIBS="$LIBS"
      
    make -j$(nproc)
    make install
    
    # Extract and copy the compiled library file
    cp libpython3.11.so "$PREFIX_DIR/lib/"
    $STRIP "$PREFIX_DIR/lib/libpython3.11.so"
    
    cd ..
fi

# 7. Copy and package libraries for Gradle skeleton
TARGET_JNI_DIR="app/src/main/jniLibs/arm64-v8a"
mkdir -p "$TARGET_JNI_DIR"

echo "Copying libpython.so to JNI directory..."
cp "$PREFIX_DIR/lib/libpython3.11.so" "$TARGET_JNI_DIR/libpython.so"

echo "Zipping standard library to libpython.zip.so..."
# Zip standard library. Exclude test suites and unused modules to minimize size.
cd "$PREFIX_DIR/python_usr/lib/python3.11"
zip -rq "$PREFIX_DIR/lib/libpython.zip.so" ./* -x "test/*" "idlelib/*" "tkinter/*" "turtledemo/*"
cd -

cp "$PREFIX_DIR/lib/libpython.zip.so" "$TARGET_JNI_DIR/libpython.zip.so"

echo "=== Python Compilation Completed Successfully ==="
echo "Artifacts placed in: $PREFIX_DIR"
echo "  Shared library: $PREFIX_DIR/lib/libpython3.11.so"
echo "  Standard Library: $PREFIX_DIR/python_usr/lib/python3.11"
echo "Packaged JNI files outputted to: $TARGET_JNI_DIR/"
