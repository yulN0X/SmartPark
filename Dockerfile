# ============================================================
# SmartPark API — Docker Image
# ============================================================
# Multi-arch: supports linux/amd64 + linux/arm64 (Raspberry Pi)
#
# Build:
#   docker build -t smartpark-api .
#
# Run:
#   docker run -d -p 8000:8000 smartpark-api
#
# API docs available at: http://localhost:8000/docs
# ============================================================

# === Stage 1: Base with system dependencies ===
FROM python:3.11-slim AS base

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install system dependencies required by OpenCV and OCR runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# === Stage 2: Install Python dependencies ===
FROM base AS deps

COPY requirements-runtime.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements-runtime.txt

# === Stage 3: Final image ===
FROM deps AS final

# Cache the lightweight OCR model during build so runtime startup does not
# depend on an internet connection on the target device.
ARG FAST_PLATE_OCR_MODEL=cct-xs-v2-global-model
ENV SMARTPARK_OCR_MODEL=${FAST_PLATE_OCR_MODEL} \
    SMARTPARK_OCR_CACHE_DIR=/app/models/fast_plate_ocr \
    SMARTPARK_ANPR_MODEL_PATH=/app/models/best.onnx
RUN mkdir -p "${SMARTPARK_OCR_CACHE_DIR}" && \
    python -c "from pathlib import Path; from fast_plate_ocr.inference import hub; hub.download_model('${FAST_PLATE_OCR_MODEL}', save_directory=Path('${SMARTPARK_OCR_CACHE_DIR}') / '${FAST_PLATE_OCR_MODEL}')"

# Copy application code
COPY api/ ./api/

# Copy lightweight trained model weights for edge inference
COPY models/best.onnx ./models/best.onnx

# Create uploads directory
RUN mkdir -p uploads models

# Expose API port
EXPOSE 8000

# Health check — ensures container is serving requests
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Labels for Docker Hub
LABEL maintainer="SmartPark Team" \
      description="SmartPark ANPR & OCR API for Smart Parking System" \
      version="1.1.0"

# Run the API server
# --host 0.0.0.0 allows connections from outside the container
# --workers 1 is sufficient for Raspberry Pi (limited resources)
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
