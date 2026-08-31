# ——— FULL IMAGE: Python + CLI Tools ———
FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive

# Force protobuf pure-Python mode — prevents "Descriptors cannot be created
# directly" crash when widevine_pb2.py (generated with old protoc) is imported
# alongside pywidevine / pyrogram which pull in newer protobuf C extensions.
# Must be set as ENV (not os.environ in code) so it's active before Python starts.
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

# 🧱 System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl ca-certificates git gcc g++ libffi-dev python3-dev build-essential \
    libssl-dev libxml2-dev libxslt1-dev pkg-config libgl1 libglib2.0-0 libnss3 libnspr4 libdbus-1-3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 libatspi2.0-0 libgtk-3-0 xdg-utils unzip \
    p7zip-full mkvtoolnix mediainfo qbittorrent-nox ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# 🎭 Playwright Chromium (for HBO Arkose browser fallback, SG proxy + Ghost Cursor)
RUN pip install --no-cache-dir playwright playwright-stealth certifi && \
    playwright install --with-deps chromium

# 📁 Working directory
WORKDIR /app

# 🐍 Python requirements
COPY requirements.txt .

RUN python -m pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir --prefer-binary -r requirements.txt && \
    pip install --no-cache-dir pyzipper

# ==================================================
# 🎥 FFmpeg (System package via apt)
# ==================================================
# We symlink the system ffmpeg to /app/utilities so your app
# code doesn't need to change where it looks for the binaries.
RUN mkdir -p /app/utilities && \
    ln -s /usr/bin/ffmpeg /app/utilities/ffmpeg && \
    ln -s /usr/bin/ffprobe /app/utilities/ffprobe

# ==================================================
# 🔐 Bento4 (mp4decrypt)
# ==================================================
RUN cd /tmp && \
    wget https://www.bok.net/Bento4/binaries/Bento4-SDK-1-6-0-640.x86_64-unknown-linux.zip && \
    unzip Bento4-SDK-1-6-0-640.x86_64-unknown-linux.zip && \
    cp Bento4-SDK-1-6-0-640.x86_64-unknown-linux/bin/mp4decrypt /app/mp4decrypt && \
    chmod +x /app/mp4decrypt && \
    rm -rf /tmp/*

# ==================================================
# 📥 N_m3u8DL-RE
# ==================================================
RUN set -eux; \
    cd /tmp; \
    wget -q https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.5.1-beta/N_m3U8DL-RE_v0.5.1-beta_linux-x64_20251029.tar.gz; \
    tar -xzf N_m3U8DL-RE_v0.5.1-beta_linux-x64_20251029.tar.gz; \
    BIN_PATH="$(find . -type f -iname 'n_m3u8dl-re' | head -n 1)"; \
    echo "Found binary at: $BIN_PATH"; \
    test -n "$BIN_PATH"; \
    mv "$BIN_PATH" /usr/local/bin/N_m3u8DL-RE; \
    chmod +x /usr/local/bin/N_m3u8DL-RE; \
    rm -rf /tmp/*

# ==================================================
# 🔗 MKVToolNix symlinks
# ==================================================
RUN ln -s /usr/bin/mkvmerge /app/mkvmerge && \
    ln -s /usr/bin/mkvinfo /app/mkvinfo && \
    ln -s /usr/bin/mkvpropedit /app/mkvpropedit && \
    ln -s /usr/bin/mkvextract /app/mkvextract

# ==================================================
# 📥 yt-dlp
# ==================================================
RUN wget -q -O /app/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp && \
    chmod +x /app/yt-dlp

# 🌊 qBittorrent for TMDB
RUN which qbittorrent-nox || echo 'qbittorrent-nox installed'
RUN ln -sf /usr/bin/qbittorrent-nox /app/qbittorrent-nox 2>/dev/null || true

# ==================================================
# 🔐 Shaka Packager (Apple TV+ / HLS DRM)
# ==================================================
RUN set -eux; \
    wget -q -O /tmp/shaka-packager https://github.com/shaka-project/shaka-packager/releases/latest/download/packager-linux-x64; \
    chmod +x /tmp/shaka-packager; \
    mv /tmp/shaka-packager /usr/local/bin/shaka-packager; \
    shaka-packager --version || echo "shaka-packager installed"

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

CMD ["bash", "-c", "qbittorrent-nox --confirm-legal-notice --webui-port=8080 -d && sleep 3 && echo 'qBittorrent started on port 8080' && "/app/entrypoint.sh"]
