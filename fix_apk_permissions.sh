#!/usr/bin/env bash
# fix_apk_permissions.sh <unsigned-apk-path> <package-prefix>
#
# Post-processes an APK to set 0755 permissions on native .so binaries.
# Gradle/AAPT2 strips execute permissions during packaging, but Android's
# PackageManager preserves zip entry permissions on extraction.
#
# Package prefix is one of: ffmpeg, python, quickjs
set -e

APK="$1"
PACKAGE="$2"

if [ -z "$APK" ] || [ ! -f "$APK" ]; then
    echo "Usage: $0 <path-to-apk> <package-prefix>"
    echo "  Package prefix is one of: ffmpeg, python, quickjs"
    exit 1
fi

FIXED="${APK}.fixed"

python3 -c "
import zipfile, stat

with zipfile.ZipFile('$APK', 'r') as zin:
    with zipfile.ZipFile('$FIXED', 'w', zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            # Only fix .so files in lib/ (native binaries)
            if item.filename.startswith('lib/') and item.filename.endswith('.so') and 'zip.so' not in item.filename:
                old_mode = (item.external_attr >> 16) & 0x1FF
                new_mode = old_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH
                item.external_attr = (new_mode << 16) | stat.S_IFREG
                print(f'  {item.filename}: {old_mode:04o} -> {new_mode:04o}')
            zout.writestr(item, data)
"

mv "$FIXED" "$APK"
echo "Fixed permissions in $APK"
