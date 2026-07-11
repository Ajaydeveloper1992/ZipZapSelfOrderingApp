#!/bin/bash
# 🚀 ZipZap Flutter Build Script
# Builds web and/or APK using values from .env
#
# Usage:
#   ./build.sh          # Build both web and APK (default)
#   ./build.sh web      # Build web only
#   ./build.sh apk      # Build APK only
#   ./build.sh both     # Build both web and APK

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Default values
DEFAULT_API_BASE_URL="http://localhost:8000/api/v1"
DEFAULT_WS_URL="ws://localhost:8000/ws"

# Read env file if it exists
if [ -f "$ENV_FILE" ]; then
  echo "📄 Reading environment from .env..."
  # Export variables, stripping quotes
  while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    
    key="${line%%=*}"
    value="${line#*=}"
    
    # Remove quotes
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    
    export "$key=$value"
  done < "$ENV_FILE"
else
  echo "⚠️  No .env file found, using defaults"
fi

# Set final values with defaults
API_BASE_URL="${API_BASE_URL:-$DEFAULT_API_BASE_URL}"
WS_URL="${WS_URL:-$DEFAULT_WS_URL}"

echo ""
echo "🔧 Build Configuration:"
echo "   API_BASE_URL: $API_BASE_URL"
echo "   WS_URL: $WS_URL"
echo ""

# Determine build target
TARGET="${1:-both}"

# Build function for web
build_web() {
  echo "🌐 Building Flutter Web..."
  flutter build web --release \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=WS_URL="$WS_URL"
  echo "✅ Web build complete: build/web/"
}

# Build function for APK
build_apk() {
  echo "📱 Building Flutter APK..."
  flutter build apk --release \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=WS_URL="$WS_URL"
  echo "✅ APK build complete: build/app/outputs/flutter-apk/app-release.apk"
}

# Execute based on target
case "$TARGET" in
  web)
    build_web
    ;;
  apk)
    build_apk
    ;;
  both)
    build_web
    echo ""
    build_apk
    ;;
  *)
    echo "❌ Unknown target: $TARGET"
    echo "   Usage: $0 [web|apk|both]"
    exit 1
    ;;
esac

echo ""
echo "🎉 Build finished!"
