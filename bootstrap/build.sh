#!/usr/bin/env bash
# Builds the dependency-free bootstrap jar (game-file installer). Pure Java, so
# it runs identically on desktop and inside the iOS Zero JVM. Tested on Windows.
# Usage: ./build.sh [output_dir]   (default: ./dist, relative to your CWD)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve the output dir relative to the CALLER's cwd (before any cd), so
# `bash ./bootstrap/build.sh runtimes` from the repo root writes to ./runtimes,
# not ./bootstrap/runtimes.
OUT_ARG="${1:-dist}"
case "$OUT_ARG" in
  /* | [A-Za-z]:*) OUT="$OUT_ARG" ;;   # absolute (unix or windows drive)
  *)               OUT="$(pwd)/$OUT_ARG" ;;
esac

mkdir -p "$SCRIPT_DIR/out" "$OUT"
javac -d "$SCRIPT_DIR/out" "$SCRIPT_DIR"/src/com/swiftmc/bootstrap/*.java
jar --create --file "$OUT/iSwiftMC-bootstrap.jar" -C "$SCRIPT_DIR/out" .
echo "built $OUT/iSwiftMC-bootstrap.jar"
