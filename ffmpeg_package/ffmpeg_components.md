# FFmpeg 7.1.1 Enabled vs Disabled Components Report

This document lists the exact components enabled and disabled in our custom-compiled FFmpeg 7.1.1 binary for the `video-downloader` Android application.

To achieve maximum performance and minimum file size (~7.5MB uncompressed, ~3MB in release package), we configure the build using `--disable-everything` as a base, and then selectively enable the following components:

---

## 1. Protocols

### Enabled Protocols
*   `file` (Local filesystem I/O)
*   `http` (Cleartext HTTP network segments)
*   `https` (Secure HTTPS network segments)
*   `tcp` (Low-level TCP sockets)
*   `udp` (Low-level UDP sockets)
*   `tls` (Transport Layer Security)
*   `crypto` (HLS segment decryption support)
*   `data` (Data URI parsing, e.g. base64 streams)

### Disabled Protocols
*   All other network and legacy protocols (e.g. FTP, RTMP, RTSP, SFTP, Gopher, etc.).

---

## 2. Codecs (Decoders & Encoders)

### Video Decoders (Playback & Demuxing)
*   `h264` (Standard AVC Video)
*   `hevc` (H.265 High Efficiency Video)
*   `vp9` (Google VP9 WebM Video)
*   `av1` (AOMedia Video 1 modern stream)
*   `png` (PNG image decoding for thumbnails)
*   `mjpeg` (JPEG image decoding for thumbnails)
*   `webp` (WebP image decoding for thumbnails)
*   `gif` (GIF image decoding)

### Video Encoders (Transcoding & Compression)
*   `libx264` (H.264 video encoding via static x264 library)
*   `png` (PNG image output conversion)
*   `mjpeg` (JPEG image output conversion)
*   `gif` (GIF image output conversion)

### Audio Decoders (Playback & Demuxing)
*   `aac` (Standard Advanced Audio Coding)
*   `opus` (High-efficiency Opus audio)
*   `mp3` (MPEG-1 Audio Layer III)
*   `flac` (Free Lossless Audio Codec)
*   `vorbis` (Ogg Vorbis audio)
*   `pcm_s16le` (Raw WAV PCM audio)

### Audio Encoders (Transcoding & Conversion)
*   `libmp3lame` (MP3 encoding via static LAME library)
*   `aac` (Native AAC encoding)
*   `opus` (Native Opus encoding)
*   `flac` (Native FLAC encoding)
*   `pcm_s16le` (Raw WAV PCM encoding)
*   `vorbis` (OGG Vorbis audio encoding)

### Subtitle Decoders & Encoders
*   `ass` (Advanced SubStation Alpha subtitles)
*   `srt` / `subrip` (SubRip text subtitles)
*   `webvtt` (Web Video Text Tracks)
*   `mov_text` (MP4/MOV native text subtitles)

### Disabled Codecs
*   All old/obsolete decoders/encoders (e.g. MPEG-1/2, H.263, RealVideo, Windows Media Video/Audio, RealAudio, etc.).

---

## 3. Demuxers & Muxers

### Enabled Demuxers (Reading Formats)
*   `mov` (MP4, MOV, M4A container parser)
*   `matroska` (MKV and WebM container parser)
*   `hls` (HTTP Live Streaming index parser)
*   `dash` (Dynamic Adaptive Streaming over HTTP parser)
*   `flv` (Flash Video stream reader)
*   `image2` / `image2pipe` (Image files reader)
*   `webp` (WebP files reader)
*   `aac` / `mp3` / `ogg` / `flac` / `wav` (Raw audio streams)
*   `ass` / `srt` / `webvtt` / `subrip` (Subtitle file formats)

### Enabled Muxers (Writing Formats)
*   `mp4` (Standard MP4 container output)
*   `mov` (MOV container output)
*   `ipod` (M4A container variant for audio metadata)
*   `matroska` (MKV container output)
*   `webm` (WebM container output)
*   `image2` / `image2pipe` (Image files output)
*   `webp` (WebP files output)
*   `aac` / `mp3` / `ogg` / `opus` / `flac` / `wav` (Audio formats writing)
*   `ass` / `srt` / `webvtt` / `mov_text` (Soft subtitle embedding tracks)

### Disabled Demuxers & Muxers
*   All legacy formats (e.g. AVI, ASF, MPEG-TS, RealMedia RM, OGG OGM, etc.).

---

## 4. Parsers & Filters

### Enabled Parsers
*   `h264`, `hevc`, `vp9`, `av1` (Video stream header splitters)
*   `aac`, `opus`, `mpegaudio` (Audio stream header splitters)
*   `png`, `mjpeg`, `webp` (Image stream header splitters)

### Enabled Filters (Processing)
*   `aformat` / `aresample` (Audio format and sample-rate conversion)
*   `scale` / `crop` (Video resizing and cropping)
*   `null` (Passthrough filter)
*   `trim` / `atrim` (Media cutting/trimming)
*   `pan` (Audio channel layout remixing, e.g. stereo-to-mono)
*   `volume` (Audio volume level adjustment)
