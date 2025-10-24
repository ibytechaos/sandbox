#!/bin/bash

#
# Build script for reverse engineered Docker image
#

set -e

# Configuration
IMAGE_NAME="sandbox-reversed"
TAG="latest"
DOCKERFILE="Dockerfile"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

main() {
    log_info "Building Docker image: ${IMAGE_NAME}:${TAG}"
    
    # Check if Dockerfile exists
    if [ ! -f "${DOCKERFILE}" ]; then
        log_error "Dockerfile not found: ${DOCKERFILE}"
        exit 1
    fi
    
    # Check if config directory exists
    if [ ! -d "config" ]; then
        log_error "config directory not found. Please run reverse_docker_image.sh first."
        exit 1
    fi
    
    # Build the image
    log_info "Starting Docker build..."
    docker build -t "${IMAGE_NAME}:${TAG}" -f "${DOCKERFILE}" .
    
    log_success "Build completed successfully!"
    log_info "Image built: ${IMAGE_NAME}:${TAG}"
    
    # Display usage information
    echo ""
    echo "=========================================="
    echo "           BUILD COMPLETED"
    echo "=========================================="
    echo ""
    echo "You can now run the image with:"
    echo "  docker run -it ${IMAGE_NAME}:${TAG}"
    echo ""
    echo "Or run with port mapping:"
    echo "  docker run -it -p 8080:8080 ${IMAGE_NAME}:${TAG}"
    echo ""
    echo "To run in background:"
    echo "  docker run -d --name sandbox ${IMAGE_NAME}:${TAG}"
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