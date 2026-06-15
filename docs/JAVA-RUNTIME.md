# The Java runtime: what "latest Java, no JIT" actually means on iOS

> **TL;DR — it's already handled.** `scripts/fetch-deps.sh` auto-extracts a
> working **iOS arm64 Java 17.0.8** runtime from PojavLauncher's public release
> IPA. You don't need to download, build, or host anything. The rest of this doc
> explains the constraints behind that choice and how to swap in a different JDK.

This is the single hardest dependency in the project. Read before assuming you
can just "bundle the latest JDK."

## The default source (what fetch-deps does automatically)
PojavLauncher's release IPA bundles a complete `java-17-openjdk` runtime built
for iOS (verified: `JAVA_VERSION=17.0.8`, `OS_ARCH=aarch64`, `OS_NAME=Darwin`,
Mach-O arm64 `lib/server/libjvm.dylib`). `fetch-deps.sh` downloads that IPA and
copies the runtime into `runtimes/jre`. The dedicated build repo's CI artifacts
expired (no builds since 2025-05), so the IPA is the reliable public source.

To use a different/newer Java, set `OPENJDK_IOS_URL` to your own iOS arm64 Zero
JRE tarball — see "Where to get the binary" below.

## iOS Java = the Zero interpreter (and that's your no-JIT mode)
The official OpenJDK iOS port (https://openjdk.org/projects/mobile/ios.html) only
runs as the **Zero** JVM variant — a pure bytecode interpreter built with:

```
bash configure --openjdk-target=aarch64-apple-ios \
               --with-jvm-variants=zero --with-libffi=<path>
make images
```

Zero has **no JIT compiler at all**. So:
- The "no JIT" requirement isn't something we configure — it's the only thing
  iOS allows. (HotSpot's C1/C2 JIT needs writable-executable memory, which a
  sideloaded iOS app can't get.)
- Expect slow execution. This is the performance ceiling. There is no faster
  option without TrollStore-level entitlements, which iOS 26.5 can't get.

## "Latest Java" — the honest ceiling
Truly-latest JDKs (24/25…) likely have **no working iOS Zero build**. The mobile
port lags. Realistically:
- **Java 17** — solid, proven on iOS via PojavLauncher.
- **Java 21** — was still maturing for iOS per the PojavLauncher tracker.
- Newer — probably nonexistent for iOS arm64.

Bundle the **newest version that actually has a working Zero build**, not the
newest version that exists.

## Where to get the binary (no stable URL — these are the real options)
1. **PojavLauncherTeam/android-openjdk-build-multiarch**, branch `buildjre17-21`.
   Open the repo's GitHub **Actions** tab (logged in), download the iOS/arm64
   `pojav` JRE artifact, host it, and set `OPENJDK_IOS_URL`.
2. **Build it yourself** on macOS with the `configure` line above. This is the
   only way to get a version/feature set exactly as you want it.

The result must extract to a JRE tree containing `lib/server/libjvm.dylib`, which
`scripts/fetch-deps.sh` verifies and the build copies into the app bundle.

## Licensing note
OpenJDK is GPL+Classpath-Exception — fine to bundle. Minecraft itself is **not**
bundled; the user downloads it with their own account.
