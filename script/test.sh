#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT_DIR/.cache/clang" "$ROOT_DIR/.build"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.cache/clang"
export XDG_CACHE_HOME="$ROOT_DIR/.cache"

swiftc -swift-version 5 \
  "$ROOT_DIR/Sources/Shiyin/Models.swift" \
  "$ROOT_DIR/Sources/Shiyin/YouTubeClient.swift" \
  "$ROOT_DIR/Tests/Smoke/main.swift" \
  -o "$ROOT_DIR/.build/shiyin-smoke"
"$ROOT_DIR/.build/shiyin-smoke"

swiftc -parse-as-library -swift-version 5 \
  "$ROOT_DIR/Sources/Shiyin/Models.swift" \
  "$ROOT_DIR/Sources/Shiyin/YouTubeClient.swift" \
  "$ROOT_DIR/Tests/AuthIntegration/main.swift" \
  -o "$ROOT_DIR/.build/shiyin-auth-integration"
"$ROOT_DIR/.build/shiyin-auth-integration"

swiftc -parse-as-library -swift-version 5 \
  "$ROOT_DIR/Sources/Shiyin/Models.swift" \
  "$ROOT_DIR/Sources/Shiyin/YouTubeClient.swift" \
  "$ROOT_DIR/Sources/Shiyin/SystemPlaybackController.swift" \
  "$ROOT_DIR/Sources/Shiyin/MusicStore.swift" \
  "$ROOT_DIR/Tests/PlaylistQueue/main.swift" \
  -o "$ROOT_DIR/.build/shiyin-playlist-queue"
"$ROOT_DIR/.build/shiyin-playlist-queue"

swiftc -parse-as-library -swift-version 5 \
  "$ROOT_DIR/Sources/Shiyin/Models.swift" \
  "$ROOT_DIR/Sources/Shiyin/YouTubeClient.swift" \
  "$ROOT_DIR/Sources/Shiyin/SystemPlaybackController.swift" \
  "$ROOT_DIR/Sources/Shiyin/MusicStore.swift" \
  "$ROOT_DIR/Tests/Playback/main.swift" \
  -o "$ROOT_DIR/.build/shiyin-playback"
"$ROOT_DIR/.build/shiyin-playback"
