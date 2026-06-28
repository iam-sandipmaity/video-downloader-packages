# Video Downloader Packages Builder

This repository compiles and packages custom binary runtimes specifically optimized for the Video Downloader Android application. 

It is structured as a multi-package repository containing modular sub-projects that can be built, signed, and released independently:

```
video-downloader-packages/
├── .github/workflows/          # Automated master CI/CD release workflow
├── ffmpeg_package/             # Custom high-performance FFmpeg 7.1.1 runtime package
│   ├── app/                    # Skeletal JNI project wrapping libffmpeg.so
│   ├── build_ffmpeg.sh         # Custom FFmpeg static compiling script
│   ├── package_apk.sh          # Gradle compilation packaging script
│   └── ...
└── python_package/             # Custom Python & yt-dlp update wrapper package (Planned)
    ├── build_python.sh         # Custom Python static compiling script placeholder
    └── README.md               # Python runtime integration documentation
```

---

## 1. FFmpeg Package (`ffmpeg_package/`)

A high-performance **FFmpeg 7.1.1** compilation pipeline optimized down to a minimal binary size (~7-8MB uncompressed, ~3MB in ZIP) by disabling unused modules while selectively compiling critical modern features.

### Capabilities Included:
*   **Network Streaming**: Statically linked `mbedTLS` for secure HTTPS downloads (HLS `.m3u8` and DASH segment files).
*   **Decryption**: Support for HLS segment decryption (`crypto` protocol).
*   **Media Trimming**: Enabled `trim` and `atrim` filters for sample-accurate and frame-accurate cutting.
*   **Video Compression**: Statically compiled and linked `libx264` for high-quality H.264 video compression.
*   **Audio Conversion**: Statically compiled and linked `libmp3lame` (LAME 3.100) for MP3 conversion.
*   **Subtitles**: Support for reading/writing subtitle tracks (`ass`, `srt`, `webvtt`, `subrip`, `mov_text`).
*   **Images**: Support for decoding WebP thumbnails (`webp` parser/decoder) and converting/saving images (`png`, `mjpeg`).

For details on local compilation and architecture, see [ffmpeg_package/README.md](ffmpeg_package/README.md).

---

## 2. Python Package (`python_package/`)

*(Planned / Future Integration)*

Designed to compile and package custom, minimal Python runtimes specifically tailored for the Video Downloader Android application to enable direct `yt-dlp` updates and footprint optimizations.

For details, see [python_package/README.md](python_package/README.md).

---

## Unified CI/CD Releases (`master.yml`)

The repository uses a single master workflow (`.github/workflows/master.yml`) to automatically compile, sign, and publish packages to GitHub Releases.

### Key Signing Setup
To sign generated APKs automatically, configure these repository secrets in **Settings -> Secrets and variables -> Actions**:
*   `RELEASE_KEYSTORE_BASE64` (or `SIGNING_KEY`): Base64 encoded private keystore (run `base64 -w 0 keystore.jks` locally to generate).
*   `RELEASE_STORE_PASSWORD` (or `KEYSTORE_PASSWORD`): Keystore file password.
*   `RELEASE_KEY_ALIAS` (or `KEY_ALIAS`): Private key alias name.
*   `RELEASE_KEY_PASSWORD` (or `KEY_PASSWORD`): Private key password.

### Workflow Triggers
Releases are triggered by pushing git tags. The workflow detects the tag format to compile and publish the correct package:
*   **FFmpeg releases**: Tagged as `ffmpeg-v*` or `v*` (e.g. `ffmpeg-v7.1.1` or `v7.1.1`).
*   **Python releases**: Tagged as `python-v*` (e.g. `python-v3.11.0`).

Example:
```bash
git tag ffmpeg-v7.1.1
git push origin ffmpeg-v7.1.1
```
The GHA runner will build, sign, and upload the companion APK as a release asset (e.g., `ffmpeg-signed-arm64-v8a.apk`) along with printing the certificate SHA-256 fingerprint in the logs for verification.
