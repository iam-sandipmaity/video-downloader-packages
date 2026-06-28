# Custom FFmpeg Package Repository & Builder

This workspace allows you to build, compile, and package your own custom FFmpeg binaries for the Video Downloader Android app from the official FFmpeg source code, ensuring total independence and control over your binaries.

---

## Architecture and Build Options

To package FFmpeg, the target binary (`libffmpeg.so`) must be placed under `app/src/main/jniLibs/arm64-v8a/` inside the skeletal project. You can compile this binary using one of the following two options.

### Option A: Automate using GitHub Actions (Recommended)
This repository includes a pre-configured GitHub Actions workflow that handles compilation and packaging automatically on GitHub's build agents, without requiring any local installation of NDK or compilers.

1. Push this workspace to your GitHub repository.
2. Go to the **Actions** tab of your repository.
3. Select the **Compile and Package FFmpeg for Android** workflow.
4. Click **Run workflow**.
5. Once completed, download the signed or unsigned update APK artifact from the workflow run.

---

### Option B: Compile Locally
If you have the Android NDK installed locally, you can compile and package FFmpeg locally.

#### Prerequisites
- A Linux compilation environment.
- Android NDK (version `r26b` or later is recommended).
- Java Development Kit (JDK 17).

#### Build Instructions
1. Copy `local.properties.example` to `local.properties`:
   ```bash
   cp local.properties.example local.properties
   ```
2. Open `local.properties` and configure `sdk.dir` and `ndk.dir` with the correct paths.
3. Run the local build script:
   ```bash
   ./build_ffmpeg.sh
   ```
   This script clones the official FFmpeg repository (tag `n7.0.1`), cross-compiles it statically for `arm64-v8a` using the NDK clang toolchain, and outputs `app/src/main/jniLibs/arm64-v8a/libffmpeg.so`.
4. Package the APK:
   ```bash
   ./package_apk.sh
   ```
   This generates `app/build/outputs/apk/release/app-release-unsigned.apk`.

---

## Signing and Deployment

To deploy your packages so that they can be parsed by the main app updater:

1. Sign the output APK using `apksigner`:
   ```bash
   apksigner sign --ks /path/to/keystore.jks --ks-key-alias my-alias app/build/outputs/apk/release/app-release-unsigned.apk
   ```
2. Verify the SHA-256 fingerprint of the signing certificate:
   ```bash
   apksigner verify --print-certs app/build/outputs/apk/release/app-release-unsigned.apk | grep -i sha-256
   ```
3. Update the main app's code in `app/src/main/java/com/localdownloader/updates/FfmpegUpdateManager.kt`:
   - Change `PACKAGE_REPOSITORY` to your own package releases repository path (e.g. `"your-username/video-downloader-packages"`).
   - Add the SHA-256 cert fingerprint to the `TRUSTED_RUNTIME_SIGNER_SHA256_DIGESTS` set.
