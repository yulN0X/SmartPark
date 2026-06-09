#!/bin/bash
# ============================================================
# SmartPark — Build & Push Multi-Architecture Docker Image
# ============================================================
# Builds for both:
#   - linux/amd64 (PC, Mac Intel, servers)
#   - linux/arm64 (Raspberry Pi 4/5, Mac Apple Silicon)
#
# Prerequisites:
#   1. Docker Desktop installed with buildx support
#   2. Logged in to Docker Hub: docker login
#
# Usage:
#   ./scripts/docker-build-push.sh <docker-hub-username>
#
# Example:
#   ./scripts/docker-build-push.sh njul
#   → Pushes: njul/smartpark-api:latest
#   → Pushes: njul/smartpark-api:v1.1.0
# ============================================================

set -euo pipefail

# --- Configuration ---
DOCKER_USERNAME="${1:?Usage: $0 <docker-hub-username>}"
IMAGE_NAME="smartpark-api"
VERSION="v1.1.0"
PLATFORMS="linux/amd64,linux/arm64"

FULL_IMAGE="${DOCKER_USERNAME}/${IMAGE_NAME}"

echo ""
echo "============================================================"
echo "  SmartPark — Docker Multi-Arch Build & Push"
echo "============================================================"
echo "  Username:   ${DOCKER_USERNAME}"
echo "  Image:      ${FULL_IMAGE}"
echo "  Version:    ${VERSION}"
echo "  Platforms:  ${PLATFORMS}"
echo "============================================================"
echo ""

# --- Step 1: Create/use buildx builder ---
BUILDER_NAME="smartpark-builder"
if ! docker buildx inspect "${BUILDER_NAME}" >/dev/null 2>&1; then
    echo "[1/4] Creating buildx builder: ${BUILDER_NAME}"
    docker buildx create --name "${BUILDER_NAME}" --use --bootstrap
else
    echo "[1/4] Using existing builder: ${BUILDER_NAME}"
    docker buildx use "${BUILDER_NAME}"
fi

# --- Step 2: Login check ---
echo "[2/4] Checking Docker Hub login..."
if ! docker info 2>/dev/null | grep -q "Username"; then
    echo "⚠ Not logged in to Docker Hub. Please run: docker login"
    exit 1
fi
echo "  ✓ Logged in"

# --- Step 3: Build and push ---
echo "[3/4] Building and pushing multi-arch image..."
echo "  This may take 10-20 minutes on first build."
echo ""

docker buildx build \
    --platform "${PLATFORMS}" \
    --tag "${FULL_IMAGE}:latest" \
    --tag "${FULL_IMAGE}:${VERSION}" \
    --push \
    .

# --- Step 4: Verify ---
echo ""
echo "[4/4] Verifying push..."
docker buildx imagetools inspect "${FULL_IMAGE}:latest"

echo ""
echo "============================================================"
echo "  ✅ SUCCESS!"
echo "============================================================"
echo ""
echo "  Image pushed: ${FULL_IMAGE}:latest"
echo "  Image pushed: ${FULL_IMAGE}:${VERSION}"
echo ""
echo "  Pull commands:"
echo "    docker pull ${FULL_IMAGE}:latest"
echo ""
echo "  Run command:"
echo "    docker run -d -p 8000:8000 ${FULL_IMAGE}:latest"
echo ""
echo "  API docs: http://localhost:8000/docs"
echo "============================================================"
