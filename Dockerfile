# ——— FULL IMAGE: Python + CLI Tools ———
FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

# 🧱 System dependencies
# 🧱 System dependencies
# Node.js + npm + all archive tools are installed at IMAGE BUILD time.
RUN apt-get update && \
    apt-get install -y --reinstall ca-certificates && \
    update-ca-certificates && \
    apt-get install -y --no-install-recommends \
    wget curl git gcc g++ libffi-dev python3-dev build-essential \
    libssl-dev libxml2-dev libxslt1-dev pkg-config libgl1 libglib2.0-0 libnss3 libnspr4 libdbus-1-3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 libatspi2.0-0 libgtk-3-0 xdg-utils \
    nodejs npm \
    tar zip unzip p7zip-full \
    mkvtoolnix mediainfo qbittorrent-nox ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# 🔧 Optional RAR support
RUN set -eux; \
    if ! command -v rar >/dev/null 2>&1; then \
        if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
            sed -i 's/Components: main/Components: main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources; \
        fi; \
        if [ -f /etc/apt/sources.list ]; then \
            sed -i -E 's/^(deb(-src)?[[:space:]].*) main([[:space:]]*)$/\1 main contrib non-free non-free-firmware/' /etc/apt/sources.list || true; \
        fi; \
        apt-get update; \
        apt-get install -y --no-install-recommends rar || true; \
        rm -rf /var/lib/apt/lists/*; \
    fi; \
    echo "Archive tools:"; \
    command -v tar || true; \
    command -v zip || true; \
    command -v unzip || true; \
    command -v 7z || true; \
    command -v rar || echo "rar not available in this Debian base image"

# 🎭 Playwright Chromium
RUN pip install --no-cache-dir playwright playwright-stealth certifi && \
    playwright install --with-deps chromium

WORKDIR /app
COPY requirements.txt .

RUN python -m pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir --prefer-binary -r requirements.txt && \
    pip install --no-cache-dir pyzipper

# 🎥 FFmpeg
RUN mkdir -p /app/utilities && \
    ln -s /usr/bin/ffmpeg /app/utilities/ffmpeg && \
    ln -s /usr/bin/ffprobe /app/utilities/ffprobe

# 🔐 Bento4 (mp4decrypt)
RUN cd /tmp && \
    wget https://www.bok.net/Bento4/binaries/Bento4-SDK-1-6-0-640.x86_64-unknown-linux.zip && \
    unzip Bento4-SDK-1-6-0-640.x86_64-unknown-linux.zip && \
    cp Bento4-SDK-1-6-0-640.x86_64-unknown-linux/bin/mp4decrypt /app/mp4decrypt && \
    chmod +x /app/mp4decrypt && \
    rm -rf /tmp/*

# 📥 N_m3u8DL-RE
RUN set -eux; \
    cd /tmp; \
    wget -q https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.5.1-beta/N_m3U8DL-RE_v0.5.1-beta_linux-x64_20251029.tar.gz; \
    tar -xzf N_m3U8DL-RE_v0.5.1-beta_linux-x64_20251029.tar.gz; \
    BIN_PATH="$(find . -type f -iname 'n_m3u8dl-re' | head -n 1)"; \
    mv "$BIN_PATH" /usr/local/bin/N_m3u8DL-RE; \
    chmod +x /usr/local/bin/N_m3u8DL-RE; \
    rm -rf /tmp/*

# 🔗 MKVToolNix symlinks
RUN ln -s /usr/bin/mkvmerge /app/mkvmerge && \
    ln -s /usr/bin/mkvinfo /app/mkvinfo && \
    ln -s /usr/bin/mkvpropedit /app/mkvpropedit && \
    ln -s /usr/bin/mkvextract /app/mkvextract

# 🔐 Shaka Packager
RUN set -eux; \
    wget -q -O /tmp/shaka-packager https://github.com/shaka-project/shaka-packager/releases/latest/download/packager-linux-x64; \
    chmod +x /tmp/shaka-packager; \
    mv /tmp/shaka-packager /usr/local/bin/shaka-packager

# ==================================================
# 📥 yt-dlp (Placed right before code COPY for max cache efficiency)
# ==================================================
RUN wget -q -O /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp

# 🌊 qBittorrent
RUN which qbittorrent-nox || echo 'qbittorrent-nox installed'
RUN ln -sf /usr/bin/qbittorrent-nox /app/qbittorrent-nox 2>/dev/null || true

# 🧩 Copy app code (Any code changes only bust the cache from here down!)
COPY . .

# 🛠️ Binary permissions
RUN chmod +x /app/mp4decrypt /usr/local/bin/yt-dlp /usr/local/bin/N_m3u8DL-RE /app/shark-bridge-exe || true

# 🛣️ PATH
ENV PATH="/app:/app/utilities:$PATH"
ENV PYTHONPATH="/app"

# ═══ qBittorrent config ═══
RUN mkdir -p /root/.config/qBittorrent && \
    printf '[LegalNotice]\nAccepted=true\n\n[Preferences]\nWebUI\\LocalHostAuth=false\nWebUI\\Port=8080\nWebUI\\Username=admin\nDownloads\\SavePath=/app/bot/downloads\n' \
    > /root/.config/qBittorrent/qBittorrent.conf

# 🚀 Entrypoint
RUN chmod +x /app/entrypoint.sh

# 🧹 IN-CONTAINER CLEANUP
RUN rm -rf /app/src /app/Cargo.toml /app/Cargo.lock /app/Dockerfile /app/bent.sh /app/requirements.txt

CMD ["bash", "/app/entrypoint.sh"]
