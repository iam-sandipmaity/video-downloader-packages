# Custom Python Package Compiler for Android (Planned)

This package folder is designed to compile and package custom, minimal Python runtimes specifically tailored for the Video Downloader Android application.

## Key Goals
1.  **Direct yt-dlp Updates**: Package and sign updates to `yt-dlp` and its Python dependencies without needing third-party wrapper updates.
2.  **Tailored Python Interpreter**: Compile a custom Python interpreter (e.g., Python 3.11/3.12) optimized for Android `arm64-v8a`.
3.  **Strict Size Reduction**: Strip unused modules from Python's standard library (like `tkinter`, `idlelib`, `test`, etc.) to minimize the final APK size.
4.  **Optimized Bundle**: Pre-compile python source files into bytecode (`.pyc`) to speed up yt-dlp launch times on device.

## Architecture
The final Python build will produce a `libpython.so` library along with a ZIP file containing the optimized standard library and `site-packages`. These assets will be packaged into a signed companion APK (similar to our FFmpeg package) so that they can be dynamically downloaded, verified, and mounted by the main application.
