# iSwiftMC

A PojavLauncher-style launcher for running **Minecraft: Java Edition** on iOS,
designed to run **without JIT** (pure-interpreter JVM) and with the **latest
OpenJDK preinstalled** inside the app bundle.

> **Status:** scaffold / work-in-progress. This repo is authored on Windows but
> **must be compiled on macOS** (locally or via the GitHub Actions macOS runner).
> You cannot build an iOS app on Windows.

---

## Why "no JIT"

iOS forbids writable-executable memory for normally-signed/sideloaded apps. The
HotSpot JIT needs exactly that (the `dynamic-codesigning` entitlement), which is
only available to TrollStore-installed apps or via a debugger attach. To stay
universally installable, this launcher runs the JVM with `-Xint` (interpreter
only). That is the supported, no-JIT mode. **Trade-off: it is slow** — expect
single/low-double-digit FPS. There is no way around this without JIT.

## Architecture

This is an *integration* project. The launcher itself is the glue; the heavy
pieces are existing open-source components:

| Component        | What it is                                   | Source |
|------------------|----------------------------------------------|--------|
| OpenJDK (iOS)    | Prebuilt arm64 JVM, run with `-Xint`         | bundled in `runtimes/` (see `scripts/fetch-deps.sh`) |
| gl4es            | OpenGL 1.x/2.x → GLES translation            | fetched by script |
| ANGLE            | GLES → Metal                                 | fetched by script |
| GLFW shim        | Fake GLFW mapping UIKit/touch → MC window    | `src/glfw_shim/` (we write this) |
| LWJGL 3          | Java bindings Minecraft links against        | downloaded at runtime |
| Game files       | Mojang version JSON, libraries, assets       | downloaded at runtime |

The **native launcher** (`src/`) loads `libjvm`, sets up JNI, configures the
classpath + JVM args (including `-Xint`), and invokes Minecraft's main class.

```
UIKit app  ─►  JVMLauncher (load libjvm, -Xint)  ─►  Minecraft main()
                     │                                    │
                     │  JNI                               │ LWJGL/GLFW calls
                     ▼                                    ▼
              classpath + assets                   GLFW shim ─► gl4es ─► ANGLE ─► Metal
```

## Repo layout

```
iSwiftMC/
├── project.yml              # XcodeGen spec (generates the .xcodeproj on macOS/CI)
├── Info.plist
├── src/
│   ├── main.m               # iOS entry point
│   ├── AppDelegate.{h,m}    # app lifecycle, launches JVM
│   ├── JVMLauncher.{h,m}    # loads libjvm, JNI invocation, -Xint config
│   └── glfw_shim/           # GLFW→UIKit shim (TODO)
├── runtimes/                # OpenJDK iOS build goes here (fetched, git-ignored)
├── scripts/
│   └── fetch-deps.sh        # downloads OpenJDK iOS + gl4es + ANGLE (run on macOS/CI)
├── .github/workflows/build.yml   # macOS CI build → unsigned .ipa artifact
└── docs/ROADMAP.md          # phased plan from scaffold → playable
```

## Building (you need macOS or CI — not Windows)

### Option A — GitHub Actions (recommended for Windows users)
1. Push this repo to GitHub.
2. The workflow in `.github/workflows/build.yml` runs on a `macos` runner:
   installs XcodeGen, runs `scripts/fetch-deps.sh`, builds an **unsigned** `.ipa`,
   and uploads it as a build artifact.
3. Download the artifact and sideload it (see Install).

### Option B — local macOS
```bash
brew install xcodegen
./scripts/fetch-deps.sh
xcodegen generate
open iSwiftMC.xcodeproj   # build for "Any iOS Device" → Product > Archive
```

## Installing (no jailbreak, no JIT)

- **AltStore / SideStore** — re-signs every 7 days. Works on any supported iOS.
- **TrollStore** — permanent, on TrollStore-compatible iOS versions. Preferred.

## What is NOT done yet

This is a scaffold. See [`docs/ROADMAP.md`](docs/ROADMAP.md). The GLFW shim,
GL pipeline wiring, Microsoft auth, and the game-file downloader are the real
work ahead.

## Legal

Minecraft is a trademark of Mojang/Microsoft. This project ships **no** Mojang
assets or code; the game is downloaded by the end user under their own license.
You must own Minecraft: Java Edition and authenticate with your own account.
