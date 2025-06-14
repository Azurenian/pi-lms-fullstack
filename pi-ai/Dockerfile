# Multi-stage build for Pi-AI service optimized for Orange Pi 5 ARM64
FROM python:3.11-slim AS base

# Install system dependencies for AI processing
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    ffmpeg \
    libsndfile1 \
    espeak-ng \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app
USER app

# Python environment setup
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PATH="/home/app/.local/bin:$PATH"

# Copy requirements first for better caching
COPY --chown=app:app requirements.txt .

# Install Python dependencies
RUN pip install --user --no-cache-dir --upgrade pip \
    && pip install --user --no-cache-dir -r requirements.txt

# Copy application code
COPY --chown=app:app . .

# Create directories for media and temp files
RUN mkdir -p media temp config logs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Start command with optimized settings for Orange Pi 5
CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000", \
     "--workers", "2", "--log-level", "info", "--access-log"]