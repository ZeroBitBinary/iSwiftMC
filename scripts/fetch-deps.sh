#!/usr/bin/env bash
# Downloads the prebuilt native dependencies. RUN ON macOS OR CI — not Windows.
# Populates runtimes/ and vendor/ (git-ignored).
#
# TURNKEY: with no env vars set, this fetches a working iOS arm64 Java 17 runtime
# automatically (see below). gl4es/ANGLE are optional until rendering is wired.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p runtimes vendor

echo "==> OpenJDK (iOS arm64, Zero interpreter — no JIT)"
# REALITY (verified): OpenJDK on iOS only runs as the *Zero* interpreter variant
# (https://openjdk.org/projects/mobile/ios.html). Zero has NO JIT — exactly the
# no-JIT mode this project wants.
#
# DEFAULT SOURCE (no setup needed): the java-17-openjdk runtime bundled inside
# PojavLauncher's public release IPA. Verified by us: Java 17.0.8, Mach-O arm64
# (magic cf fa ed fe, cputype arm64), with lib/server/libjvm.dylib. The
# android-openjdk-build-multiarch CI artifacts have expired (no builds since
# 2025-05), so the IPA is the reliable public source.
#
# OVERRIDE: set OPENJDK_IOS_URL to your own iOS arm64 Zero JRE tarball (extracted
# with --strip-components=1) to use a different/newer Java.
rm -rf runtimes/jre && mkdir -p runtimes/jre
if [ -n "${OPENJDK_IOS_URL:-}" ]; then
  echo "    using OPENJDK_IOS_URL override"
  curl -L "$OPENJDK_IOS_URL" -o /tmp/jre.tar.gz
  tar -xzf /tmp/jre.tar.gz -C runtimes/jre --strip-components=1
else
  POJAV_IPA_URL="${POJAV_IPA_URL:-https://github.com/PojavLauncherTeam/PojavLauncher_iOS/releases/download/v2.2/net.kdt.pojavlauncher-2.2-ios.ipa}"
  echo "    extracting bundled JRE from $POJAV_IPA_URL"
  curl -L "$POJAV_IPA_URL" -o /tmp/pojav.ipa
  rm -rf /tmp/pojav_extract && mkdir -p /tmp/pojav_extract
  unzip -qqo /tmp/pojav.ipa -d /tmp/pojav_extract
  JRE_SRC="$(find /tmp/pojav_extract -type d -name 'java-17-openjdk' | head -1)"
  test -n "$JRE_SRC" || { echo "ERROR: java-17-openjdk not found in IPA"; exit 1; }
  cp -R "$JRE_SRC/." runtimes/jre/
fi
test -f runtimes/jre/lib/server/libjvm.dylib \
  || { echo "ERROR: JRE has no lib/server/libjvm.dylib"; exit 1; }
echo "    JRE ready: $(grep -m1 JAVA_VERSION runtimes/jre/release)"

echo "==> gl4es (OpenGL -> GLES)  [optional until rendering, ROADMAP phase 2]"
if [ -n "${GL4ES_IOS_URL:-}" ]; then
  curl -L "$GL4ES_IOS_URL" -o vendor/libgl4es.dylib
else
  echo "    GL4ES_IOS_URL unset; skipping (JVM boots fine without it)"
fi

echo "==> ANGLE (GLES -> Metal)  [optional until rendering, ROADMAP phase 2]"
if [ -n "${ANGLE_IOS_URL:-}" ]; then
  curl -L "$ANGLE_IOS_URL" -o vendor/angle-ios.zip
  unzip -o vendor/angle-ios.zip -d vendor/angle
else
  echo "    ANGLE_IOS_URL unset; skipping (JVM boots fine without it)"
fi

echo "==> done. runtimes/ populated; vendor/ optional."
echo "    LWJGL jars + Mojang game files are downloaded at runtime, not here."
