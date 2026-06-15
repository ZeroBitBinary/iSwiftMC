# iSwiftMC bootstrap

A tiny, dependency-free Java program that downloads the Minecraft files a chosen
version needs: the **client jar**, **libraries**, and **assets**. It runs
unchanged inside the bundled iOS Zero JVM (it's plain JVM code, no third-party
libraries — even the JSON parser is hand-rolled in `Json.java`).

## What it does
- Fetches Mojang's `version_manifest_v2.json`, resolves a version id to its JSON.
- Downloads client jar + libraries + assets into a standard `.minecraft`-style
  layout, **verifying every file's SHA-1** and skipping files already present.
- **iOS-aware:** skips native/desktop-only libraries (LWJGL `natives-*`,
  anything gated by an OS rule). iSwiftMC supplies its own iOS natives + GL shim.

## Build
```bash
./build.sh            # -> dist/iSwiftMC-bootstrap.jar
./build.sh runtimes   # -> runtimes/iSwiftMC-bootstrap.jar (what CI does)
```

## Run (works on desktop too — that's how it's tested)
```bash
# Resolve only, no large download — prints the file/byte plan:
java -cp dist/iSwiftMC-bootstrap.jar com.swiftmc.bootstrap.GameInstaller 1.20.1 ./game --dry-run

# Full install:
java -cp dist/iSwiftMC-bootstrap.jar com.swiftmc.bootstrap.GameInstaller 1.20.1 ./game
```

Verified working against Mojang's live API (e.g. 1.20.1 → 43 libs kept, 45
native/OS-specific skipped, 3597 assets, ~691 MiB; SHA-1 verification confirmed).

## On-device role
On iOS the launcher runs this as the JVM's first main class to populate the game
directory, then chains into `net.minecraft.client.main.Main` (ROADMAP phase 3).
Note: the **native LWJGL/GL bits it deliberately skips are the hard part still
ahead** — downloading the files is necessary but not sufficient to render a frame.
