# Dockerfile for ghcr.io/agent-infra/sandbox reverse engineering
# Based on analysis of the original image

# Use Ubuntu 25.10 as base image (user specified)
FROM ubuntu:25.10

# Set build arguments
ARG TARGETARCH
ARG APT_MIRROR_HOST=
ARG WEBSOCAT_URL=
ARG NOVNC_URL=https://github.com/novnc/noVNC.git
ARG BROWSER_SOURCE=rs
ARG RELEASE

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV TZ=Asia/Singapore
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Browser and application environment variables
ENV BROWSER_REMOTE_DEBUGGING_PORT=9222
ENV BROWSER_COMMANDLINE_ARGS="--disable-backgrounding-occluded-windows --disable-background-timer-throttling --disable-blink-features=AutomationControlled --disable-dev-shm-usage --disable-external-intent-requests --disable-features=IPH_DesktopCustomizeChrome,IsolateOrigins,site-per-proces --disable-focus-on-load --disable-gpu --disable-infobars --disable-popup-blocking --disable-prompt-on-repost --disable-renderer-backgrounding --disable-site-isolation-trials --disable-web-security --disable-window-activation --mute-audio --no-default-browser-check --no-first-run --noerrdialogs --remote-allow-origins=* --remote-debugging-port=9222 --suppress-message-center-popups --start-maximized"

# Service ports and configuration
ENV BROWSER_EXTRA_ARGS=""
ENV DNS_OVER_HTTPS_TEMPLATES=""
ENV LOG_DIR=/var/log/gem
ENV JWT_PUBLIC_KEY=""
ENV VNC_SERVER_PORT=5900
ENV WEBSOCKET_PROXY_PORT=6080
ENV GEM_SERVER_PORT=8088
ENV MCP_SERVER_PORT=8089
ENV PUBLIC_PORT=8080
ENV AUTH_BACKEND_PORT=8081
ENV WAIT_PORTS=8091
ENV WAIT_TIMEOUT=300
ENV WAIT_INTERVAL=0.25
ENV MCP_HUB_PORT=8079
ENV SANDBOX_SRV_PORT=8091
ENV JUPYTER_LAB_PORT=8888
ENV CODE_SERVER_PORT=8200
ENV MCP_SERVER_BROWSER_PORT=8100
ENV TINYPROXY_PORT=8118
ENV MCP_SERVER_CHROME_DEVTOOLS_PORT=8102
ENV MAX_SHELL_SESSIONS=50

# Puppeteer configuration
ENV PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/browser
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV BROWSER_NO_SANDBOX=--no-sandbox
ENV BROWSER_USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

# UV tool configuration
ENV UV_TOOL_BIN_DIR=/usr/local/bin/
ENV UV_TOOL_DIR=/usr/local/share/uv/tools

# Install system dependencies and tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    python3-setuptools \
    python3-dev \
    nodejs \
    npm \
    nginx \
    supervisor \
    xvfb \
    x11vnc \
    openbox \
    tinyproxy \
    netcat-openbsd \
    locales \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    chromium-browser \
    firefox \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files (matching original image structure)
COPY config/ /opt/

# Set up browser control script
COPY config/gem/browser-ctl.sh /opt/gem/browser-ctl.sh
RUN chmod +x /opt/gem/browser-ctl.sh

# Copy MCP control script  
COPY config/gem/mcp-ctl.sh /opt/gem/mcp-ctl.sh
RUN chmod +x /opt/gem/mcp-ctl.sh

# Install Python dependencies for gem-server
WORKDIR /opt/gem-server
RUN if [ -f pyproject.toml ]; then \
    pip3 install --break-system-packages --ignore-installed -e . ; \
    fi

# Set up Jupyter Lab
RUN pip3 install --break-system-packages jupyterlab

# Set up Code Server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Create necessary directories
RUN mkdir -p /opt/runtime /opt/terminal \
    && mkdir -p /var/log/supervisor \
    && mkdir -p /home/gem \
    && useradd -m -s /bin/bash gem

# Set up health check
HEALTHCHECK --interval=10s --timeout=5s --retries=8 \
    CMD nc -z localhost ${BROWSER_REMOTE_DEBUGGING_PORT} || exit 1

# Expose port
EXPOSE 8080

# Set working directory
WORKDIR /

# Add labels to match original image
LABEL org.opencontainers.image.ref.name="ubuntu"
LABEL org.opencontainers.image.version="22.04"
LABEL version="1.0.0.143"

# Set entrypoint to match original image
ENTRYPOINT ["/opt/gem/run.sh"]