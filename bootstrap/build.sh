#!/usr/bin/env bash
# Builds the dependency-free bootstrap jar (game-file installer). Pure Java, so
# it runs identically on desktop and inside the iOS Zero JVM. Tested on Windows.
# Usage: ./build.sh [output_dir]   (default: ./dist)
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-dist}"
mkdir -p out "$OUT"
javac -d out src/com/swiftmc/bootstrap/*.java
jar --create --file "$OUT/iSwiftMC-bootstrap.jar" -C out .
echo "built $OUT/iSwiftMC-bootstrap.jar"
