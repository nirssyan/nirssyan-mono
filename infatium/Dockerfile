# Multi-stage Dockerfile for Flutter Web Application
# Stage 1: Build Flutter web app
FROM debian:latest AS build

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Clone Flutter SDK (stable channel, shallow clone for faster build)
RUN git clone -b stable --depth 1 https://github.com/flutter/flutter.git /usr/local/flutter

# Set Flutter environment variables
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Create flutter user for security
RUN useradd -m -s /bin/bash flutter && \
    chown -R flutter:flutter /usr/local/flutter && \
    mkdir -p /app && \
    chown -R flutter:flutter /app

# Switch to flutter user
USER flutter

# Run flutter doctor
RUN flutter doctor -v

# Enable Flutter web and ensure latest stable version
RUN flutter upgrade
RUN flutter config --enable-web

# Set working directory
WORKDIR /app

# Copy project files
COPY --chown=flutter:flutter pubspec.* ./
RUN flutter pub get

COPY --chown=flutter:flutter . .

# Build arguments - all required secrets
ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY
ARG API_KEY

# Build arguments - optional feature flags
ARG ENABLE_MONETIZATION=false
ARG ENABLE_SUBSCRIPTION=false

# Build Flutter web app
RUN flutter build web --release \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY} \
    --dart-define=API_KEY=${API_KEY} \
    --dart-define=ENABLE_MONETIZATION=${ENABLE_MONETIZATION} \
    --dart-define=ENABLE_SUBSCRIPTION=${ENABLE_SUBSCRIPTION}

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy built web app from build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
