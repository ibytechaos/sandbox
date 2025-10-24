#!/bin/bash

#
# Docker Image Reverse Engineering Script
# This script automates the process of reverse engineering a Docker image
# and extracting configuration files needed for rebuilding
#

set -e
set -u

# Configuration
IMAGE_NAME="${1:-ghcr.io/agent-infra/sandbox}"
CONTAINER_NAME="reverse-engineering-container"
EXTRACT_DIR="config"
DOCKERFILE_NAME="Dockerfile.reversed"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    log_info "Cleaning up..."
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    fi
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

main() {
    log_info "Starting Docker image reverse engineering for: ${IMAGE_NAME}"
    
    # Step 1: Pull the image
    log_info "Pulling Docker image..."
    docker pull "${IMAGE_NAME}"
    log_success "Image pulled successfully"
    
    # Step 2: Analyze image information
    log_info "Analyzing image information..."
    docker inspect "${IMAGE_NAME}" > "${IMAGE_NAME//\//_}_inspect.json"
    docker history --no-trunc "${IMAGE_NAME}" > "${IMAGE_NAME//\//_}_history.txt"
    log_success "Image analysis completed"
    
    # Step 3: Start container with tail command
    log_info "Starting container for file extraction..."
    docker run -d --name "${CONTAINER_NAME}" "${IMAGE_NAME}" tail -f /dev/null
    log_success "Container started successfully"
    
    # Step 4: Create extraction directory
    log_info "Creating extraction directory..."
    rm -rf "${EXTRACT_DIR}"
    mkdir -p "${EXTRACT_DIR}"
    
    # Step 5: Extract important directories
    log_info "Extracting configuration files..."
    
    # Extract /opt directory (contains most application configs)
    if docker exec "${CONTAINER_NAME}" test -d /opt; then
        log_info "Extracting /opt directory..."
        docker cp "${CONTAINER_NAME}:/opt/" "${EXTRACT_DIR}/"
        log_success "/opt directory extracted"
    fi
    
    # Extract /etc directory (system configurations)
    if docker exec "${CONTAINER_NAME}" test -d /etc; then
        log_info "Extracting /etc directory..."
        docker cp "${CONTAINER_NAME}:/etc/" "${EXTRACT_DIR}/"
        log_success "/etc directory extracted"
    fi
    
    # Extract /usr/local directory (locally installed software)
    if docker exec "${CONTAINER_NAME}" test -d /usr/local; then
        log_info "Extracting /usr/local directory..."
        docker cp "${CONTAINER_NAME}:/usr/local/" "${EXTRACT_DIR}/"
        log_success "/usr/local directory extracted"
    fi
    
    # Extract /home directory (user configurations)
    if docker exec "${CONTAINER_NAME}" test -d /home; then
        log_info "Extracting /home directory..."
        docker cp "${CONTAINER_NAME}:/home/" "${EXTRACT_DIR}/"
        log_success "/home directory extracted"
    fi
    
    # Step 6: Generate Dockerfile template
    log_info "Generating Dockerfile template..."
    generate_dockerfile_template
    log_success "Dockerfile template generated"
    
    # Step 7: Generate build script
    log_info "Generating build script..."
    generate_build_script
    log_success "Build script generated"
    
    # Step 8: Display summary
    display_summary
    
    log_success "Reverse engineering completed successfully!"
}

generate_dockerfile_template() {
    cat > "${DOCKERFILE_NAME}" << 'EOF'
# Reverse engineered Dockerfile
# Generated automatically from image analysis

# Base image (detected from image inspection)
FROM ubuntu:22.04

# Build arguments
ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive

# Environment variables (extracted from image inspection)
ENV LANG=en_US.UTF-8
ENV TZ=Asia/Singapore
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    nginx \
    supervisor \
    xvfb \
    x11vnc \
    openbox \
    tinyproxy \
    netcat \
    locales \
    ca-certificates \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy extracted configuration files
COPY config/opt/ /opt/
COPY config/etc/ /etc/
COPY config/usr/local/ /usr/local/
COPY config/home/ /home/

# Set executable permissions for scripts
RUN find /opt -name "*.sh" -type f -exec chmod +x {} \;

# Create necessary directories and users
RUN mkdir -p /var/log/supervisor \
    && useradd -m -s /bin/bash gem || true

# Health check (if applicable)
HEALTHCHECK --interval=10s --timeout=5s --retries=8 \
    CMD nc -z localhost 9222 || exit 1

# Expose ports (adjust based on your analysis)
EXPOSE 8080

# Default command
CMD ["/bin/bash"]
EOF
}

generate_build_script() {
    cat > "scripts/build_image.sh" << 'EOF'
#!/bin/bash

# Build script for reverse engineered Docker image

set -e

IMAGE_NAME="sandbox-reversed"
TAG="latest"

echo "Building Docker image: ${IMAGE_NAME}:${TAG}"

# Build the image
docker build -t "${IMAGE_NAME}:${TAG}" .

echo "Build completed successfully!"
echo "You can run the image with: docker run -it ${IMAGE_NAME}:${TAG}"
EOF
    
    chmod +x "scripts/build_image.sh"
}

display_summary() {
    echo ""
    echo "=========================================="
    echo "         REVERSE ENGINEERING SUMMARY"
    echo "=========================================="
    echo ""
    echo "Files generated:"
    echo "  - ${DOCKERFILE_NAME}                 (Reverse engineered Dockerfile)"
    echo "  - ${IMAGE_NAME//\//_}_inspect.json   (Image inspection data)"
    echo "  - ${IMAGE_NAME//\//_}_history.txt    (Image build history)"
    echo "  - scripts/build_image.sh             (Build script)"
    echo ""
    echo "Directories extracted:"
    echo "  - ${EXTRACT_DIR}/opt/                (Application configurations)"
    echo "  - ${EXTRACT_DIR}/etc/                (System configurations)"
    echo "  - ${EXTRACT_DIR}/usr/local/          (Local installations)"
    echo "  - ${EXTRACT_DIR}/home/               (User configurations)"
    echo ""
    echo "Next steps:"
    echo "  1. Review and customize ${DOCKERFILE_NAME}"
    echo "  2. Run: ./scripts/build_image.sh"
    echo "  3. Test the rebuilt image"
    echo ""
    echo "Note: You may need to adjust the Dockerfile based on"
    echo "      specific requirements and dependencies."
    echo ""
}

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running"
    exit 1
fi

# Run main function
main "$@"