# Custom FFmpeg Package Repository & Builder

This workspace allows you to build, compile, and package your own custom FFmpeg binaries for the Video Downloader Android app from the official FFmpeg source code.

This build is configured with **FFmpeg 7.1.1** (matching the competitor's engine version) and optimized down to a minimal binary size (~7-8MB uncompressed, ~3MB in ZIP) by disabling unused codecs while selectively integrating critical modern features.

---

## Features Built-In

*   **Network Streaming**: Statically linked `mbedTLS` for secure HTTPS downloads (HLS `.m3u8` and DASH segment files).
*   **Media Trimming**: Enabled `trim` and `atrim` filters for sample-accurate and frame-accurate video and audio cutting.
*   **Video Encoding**: Statically compiled and linked `libx264` for high-quality H.264 video compression and conversion.
*   **Audio Encoding**: Statically compiled and linked `libmp3lame` (LAME 3.100) for MP3 audio conversion, alongside native encoders (`aac`, `opus`, `flac`).
*   **Link-Time Optimization (LTO)**: Strips unused dead symbols and inline functions during compilation, minimizing binary file size.

---

## Architecture and Build Options

To package FFmpeg, the target binary (`libffmpeg.so`) must be placed under `app/src/main/jniLibs/arm64-v8a/` inside the skeletal project. You can compile this binary using one of the following two options.

### Option A: Automate using GitHub Actions (Recommended)
This repository includes a pre-configured GitHub Actions workflow that handles compilation, key signing, and release publishing automatically on GitHub's build agents.

#### 1. Setup Key Signing Secrets (Actions)
To sign your APK automatically in GitHub Actions, add these secrets to your `video-downloader-packages` repository settings (**Settings -> Secrets and variables -> Actions**):
*   `RELEASE_KEYSTORE_BASE64` (or `SIGNING_KEY`): Base64 encoded private keystore (run `base64 -w 0 keystore.jks` locally to generate).
*   `RELEASE_STORE_PASSWORD` (or `KEYSTORE_PASSWORD`): Keystore file password.
*   `RELEASE_KEY_ALIAS` (or `KEY_ALIAS`): Private key alias name.
*   `RELEASE_KEY_PASSWORD` (or `KEY_PASSWORD`): Private key password.

#### 2. Push a Release Tag
To trigger the automated rebuild and publication of the signed assets:
```bash
git tag v7.1.1
git push origin v7.1.1
```
The GHA runner will:
1. Compile FFmpeg 7.1.1 and its dependencies statically.
2. Package it inside the APK.
3. Sign the APK using your secrets and print the certificate **SHA-256 fingerprint** in the logs (under the **"Sign Android Release APK"** step).
4. Create/update a GitHub Release named `v7.1.1` and upload the assets:
    *   `ffmpeg-signed-arm64-v8a.apk`
    *   `ffmpeg-unsigned-arm64-v8a.apk`

---

### Option B: Compile Locally
If you have the Android NDK installed locally, you can compile and package FFmpeg locally.

#### Prerequisites
*   A Linux compilation environment.
*   Android NDK (version `r26b` is recommended).
*   Java Development Kit (JDK 17).

#### Build Instructions
1.  Copy `local.properties.example` to `local.properties`:
    ```bash
    cp local.properties.example local.properties
    ```
2.  Open `local.properties` and configure `sdk.dir` and `ndk.dir` with the correct paths.
3.  Run the local build script:
    ```bash
    ./build_ffmpeg.sh
    ```
    This script clones the dependencies (`mbedtls`, `x264`, `lame`), compiles them statically, compiles FFmpeg 7.1.1, and outputs the binary to `app/src/main/jniLibs/arm64-v8a/libffmpeg.so`.
4.  Package the APK:
    ```bash
    ./package_apk.sh
    ```
    This generates `app/build/outputs/apk/release/app-release-unsigned.apk`.

---

## Signing and Integration with Main App

To deploy your packages so that they are parsed and trusted by the main app updater:

1.  Verify the SHA-256 fingerprint of the signing certificate:
    ```bash
    apksigner verify --print-certs app/build/outputs/apk/release/ffmpeg-signed-arm64-v8a.apk | grep -i sha-256
    ```
2.  Update the main app's code in `app/src/main/java/com/localdownloader/updates/FfmpegUpdateManager.kt`:
    *   Change `PACKAGE_REPOSITORY` to your own package releases repository path (e.g. `"your-username/video-downloader-packages"`).
    *   Add the SHA-256 cert fingerprint to the `TRUSTED_RUNTIME_SIGNER_SHA256_DIGESTS` set so the app trusts and extracts your custom binary.
