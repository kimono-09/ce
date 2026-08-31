# ——— FULL IMAGE: Python + CLI Tools ———
FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

# 🧱 System dependencies (Added upx-ucl for binary packing)
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl ca-certificates git gcc g++ libffi-dev python3-dev build-essential \
    libssl-dev libxml2-dev libxslt1-dev pkg-config libgl1 xdg-utils unzip \
    p7zip-full mkvtoolnix mediainfo qbittorrent-nox ffmpeg upx-ucl \
    && rm -rf /var/lib/apt/lists/*

# 📁 Working directory
WORKDIR /app

# 🐍 Python requirements
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install pyzipper requests

# ==================================================
# 🎥 FFmpeg & 🔐 Bento4
# ==================================================
RUN mkdir -p /app/utilities && \
    ln -s /usr/bin/ffmpeg /app/utilities/ffmpeg && \
    ln -s /usr/bin/ffprobe /app/utilities/ffprobe

RUN cd /tmp && \
    wget https://www.bok.net/Bento4/binaries/Bento4-SDK-1-6-0-640.x86_64-unknown-linux.zip && \
    unzip Bento4-SDK-1-6-0-640.x86_64-unknown-linux.zip && \
    cp Bento4-SDK-1-6-0-640.x86_64-unknown-linux/bin/mp4decrypt /app/mp4decrypt && \
    chmod +x /app/mp4decrypt && \
    rm -rf /tmp/*

# ==================================================
# 📥 N_m3u8DL-RE & 🔗 MKVToolNix
# ==================================================
RUN set -eux; \
    cd /tmp; \
    wget -q https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.5.1-beta/N_m3U8DL-RE_v0.5.1-beta_linux-x64_20251029.tar.gz; \
    tar -xzf N_m3U8DL-RE_v0.5.1-beta_linux-x64_20251029.tar.gz; \
    BIN_PATH="$(find . -type f -iname 'n_m3u8dl-re' | head -n 1)"; \
    mv "$BIN_PATH" /usr/local/bin/N_m3u8DL-RE; \
    chmod +x /usr/local/bin/N_m3u8DL-RE; \
    rm -rf /tmp/*

RUN ln -s /usr/bin/mkvmerge /app/mkvmerge && \
    ln -s /usr/bin/mkvinfo /app/mkvinfo && \
    ln -s /usr/bin/mkvpropedit /app/mkvpropedit && \
    ln -s /usr/bin/mkvextract /app/mkvextract

# ==================================================
# 📥 yt-dlp & 🌊 qBittorrent & 🔐 Shaka Packager
# ==================================================
RUN wget -q -O /app/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp && \
    chmod +x /app/yt-dlp

RUN ln -sf /usr/bin/qbittorrent-nox /app/qbittorrent-nox 2>/dev/null || true

RUN set -eux; \
    wget -q -O /tmp/shaka-packager https://github.com/shaka-project/shaka-packager/releases/latest/download/packager-linux-x64; \
    chmod +x /tmp/shaka-packager; \
    mv /tmp/shaka-packager /usr/local/bin/shaka-packager

# 🧩 Copy app code
COPY . .

# 🛠️ Binary permissions
RUN chmod +x /app/mp4decrypt /app/yt-dlp /usr/local/bin/N_m3u8DL-RE /app/shark-bridge-exe || true

# 🔥 THE ULTIMATE ANTI-FORENSICS MOVE: UPX PACKING
# This heavily compresses and scrambles the Rust binary so decompilers fail.
RUN upx --best --lzma /app/shark-bridge-exe || echo "UPX packing skipped (already packed or incompatible format)"

# 🛣️ PATH
ENV PATH="/app:/app/utilities:$PATH"
ENV PYTHONPATH="/app"

# ═══ qBittorrent config ═══
RUN mkdir -p /root/.config/qBittorrent && \
    printf '[LegalNotice]\nAccepted=true\n\n[Preferences]\nWebUI\\LocalHostAuth=false\nWebUI\\Port=8080\nWebUI\\Username=admin\nDownloads\\SavePath=/app/bot/downloads\n' \
    > /root/.config/qBittorrent/qBittorrent.conf

# 🚀 Entrypoint
RUN chmod +x /app/entrypoint.sh

# 🧹 IN-CONTAINER CLEANUP: Remove source code, keeping only the packed binary
RUN rm -rf /app/src /app/Cargo.toml /app/Cargo.lock /app/Dockerfile /app/bent.sh /app/requirements.txt

CMD ["bash", "/app/entrypoint.sh"]
