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
export CFLAGS="-fPIC"
export CXXFLAGS="-fPIC"

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
    OLD_CFLAGS="$CFLAGS"
    OLD_CXXFLAGS="$CXXFLAGS"
    OLD_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
    OLD_PKG_CONFIG="$PKG_CONFIG"
    OLD_CPPFLAGS="$CPPFLAGS"
    OLD_LDFLAGS="$LDFLAGS"
    OLD_LIBS="$LIBS"
    
    # Unset them so host python configure detects the host gcc/clang and native headers
    unset CC CXX AR RANLIB STRIP READELF CFLAGS CXXFLAGS PKG_CONFIG_PATH PKG_CONFIG CPPFLAGS LDFLAGS LIBS
    
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
    export CFLAGS="$OLD_CFLAGS"
    export CXXFLAGS="$OLD_CXXFLAGS"
    export PKG_CONFIG_PATH="$OLD_PKG_CONFIG_PATH"
    export PKG_CONFIG="$OLD_PKG_CONFIG"
    export CPPFLAGS="$OLD_CPPFLAGS"
    export LDFLAGS="$OLD_LDFLAGS"
    export LIBS="$OLD_LIBS"
fi

# 6. Cross-Compile Target Python for Android arm64-v8a
if [ ! -f "python-target/python" ]; then
    echo "Cross-compiling Target Python for Android..."
    mkdir -p python-target
    cp -R python-source/* python-target/ || true
    cd python-target
    
    # Create Setup.local to statically link all essential C extension modules.
    # This prevents loading errors from zipimport on Android.
    cat << 'EOF' > Modules/Setup.local
*static*
_ssl _ssl.c -lssl -lcrypto
_hashlib _hashopenssl.c -lcrypto
_socket socketmodule.c
_json _json.c
select selectmodule.c
cmath cmathmodule.c
math mathmodule.c
_struct _struct.c
_ctypes _ctypes/_ctypes.c _ctypes/callbacks.c _ctypes/callproc.c _ctypes/stgdict.c _ctypes/cfield.c -ldl -lffi -DHAVE_FFI_PREP_CIF_VAR -DHAVE_FFI_PREP_CLOSURE_LOC -DHAVE_FFI_CLOSURE_ALLOC
array arraymodule.c
_asyncio _asynciomodule.c
_bisect _bisectmodule.c
_contextvars _contextvarsmodule.c
_csv _csv.c
_datetime _datetimemodule.c
_decimal _decimal/_decimal.c
_elementtree _elementtree.c
_heapq _heapqmodule.c
_multiprocessing _multiprocessing/multiprocessing.c _multiprocessing/semaphore.c
_opcode _opcode.c
_pickle _pickle.c
_posixsubprocess _posixsubprocess.c
_queue _queuemodule.c
_random _randommodule.c
_zoneinfo _zoneinfo.c
binascii binascii.c
fcntl fcntlmodule.c
grp grpmodule.c
mmap mmapmodule.c
pyexpat pyexpat.c
termios termios.c
unicodedata unicodedata.c
zlib zlibmodule.c -lz
_codecs_cn cjkcodecs/_codecs_cn.c
_codecs_hk cjkcodecs/_codecs_hk.c
_codecs_iso2022 cjkcodecs/_codecs_iso2022.c
_codecs_jp cjkcodecs/_codecs_jp.c
_codecs_kr cjkcodecs/_codecs_kr.c
_codecs_tw cjkcodecs/_codecs_tw.c
_multibytecodec cjkcodecs/multibytecodec.c
EOF
    
    export PKG_CONFIG_PATH="$PREFIX_DIR/lib/pkgconfig"
    export PKG_CONFIG="pkg-config"
    export CPPFLAGS="-I$PREFIX_DIR/include"
    export LDFLAGS="-L$PREFIX_DIR/lib"
    export LIBS="-lssl -lcrypto -lffi -lz"
    
    ./configure \
      --host=aarch64-linux-android \
      --build=x86_64-pc-linux-gnu \
      --disable-shared \
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
      CXX="$CXX" \
      AR="$AR" \
      RANLIB="$RANLIB" \
      STRIP="$STRIP" \
      READELF="$READELF" \
      CFLAGS="$CFLAGS" \
      CXXFLAGS="$CXXFLAGS" \
      CPPFLAGS="$CPPFLAGS" \
      LDFLAGS="$LDFLAGS" \
      LIBS="$LIBS"
      
    make -j$(nproc)
    make install
    
    cd ..
fi

# 7. Copy and package libraries for Gradle skeleton
TARGET_JNI_DIR="app/src/main/jniLibs/arm64-v8a"
mkdir -p "$TARGET_JNI_DIR"

echo "Copying python executable as libpython.so to JNI directory..."
cp python-target/python "$TARGET_JNI_DIR/libpython.so"
$STRIP "$TARGET_JNI_DIR/libpython.so"

# We do not copy libpython3.11.so since it is built statically

echo "Zipping standard library to libpython.zip.so..."
# Zip standard library. Exclude test suites and unused modules to minimize size.
cd "$PREFIX_DIR/python_usr/lib/python3.11"
    zip -rq "$PREFIX_DIR/lib/libpython.zip.so" ./* -x "test/*" "idlelib/*" "tkinter/*" "turtledemo/*" "ensurepip/*" "config-3.11-aarch64-linux-android/*" "lib2to3/*" "unittest/*" "pydoc_data/*" "sqlite3/*" "distutils/*" "**/__pycache__/*" "lib-dynload/*"
cd -

cp "$PREFIX_DIR/lib/libpython.zip.so" "$TARGET_JNI_DIR/libpython.zip.so"

# Ensure native binaries have execute permission so Android PackageManager
# extracts them with the correct mode from the APK zip entry.
echo "Setting execute permission on native binaries..."
chmod 755 "$TARGET_JNI_DIR/libpython.so"
chmod 755 "$TARGET_JNI_DIR/libpython3.11.so"

echo "=== Python Compilation Completed Successfully ==="
echo "Artifacts placed in: $PREFIX_DIR"
echo "  Standalone binary: $PREFIX_DIR/lib/libpython.so"
echo "  Standard Library: $PREFIX_DIR/python_usr/lib/python3.11"
echo "Packaged JNI files outputted to: $TARGET_JNI_DIR/"
