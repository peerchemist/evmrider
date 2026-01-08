#!/bin/sh
# A script to build the web app.

# Exit immediately if a command exits with a non-zero status.
set -e

# Build the Flutter web app.
echo "Building Flutter web app..."
flutter build web --release --wasm --no-tree-shake-icons

echo "Build complete."
