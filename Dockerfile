# syntax=docker/dockerfile:1.4
# ZipZap Flutter Web App Dockerfile
# Multi-stage build: Flutter build + Nginx serve

# Build stage
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Build arguments for API URL configuration (fallback values)
ARG API_BASE_URL=http://localhost:8000/api/v1
ARG WS_URL=ws://localhost:8000/ws

# Build web app with API URL passed via dart-define
# Supports BuildKit secret: load env vars from /run/secrets/zipzap_env if available
RUN --mount=type=secret,id=zipzap_env,target=/run/secrets/zipzap_env \
    if [ -f /run/secrets/zipzap_env ]; then \
      API_BASE_URL=$(grep -E '^API_BASE_URL=' /run/secrets/zipzap_env | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "$API_BASE_URL"); \
      WS_URL=$(grep -E '^WS_URL=' /run/secrets/zipzap_env | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "$WS_URL"); \
    fi && \
    flutter build web --release \
      --dart-define=API_BASE_URL=${API_BASE_URL} \
      --dart-define=WS_URL=${WS_URL}

# Production stage - Nginx
FROM nginx:alpine

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built web app
COPY --from=builder /app/build/web /usr/share/nginx/html

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
