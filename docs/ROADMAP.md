# Roadmap: scaffold → playable

Phased so each step produces something you can verify on a real device via CI.

## Phase 0 — scaffold (this commit)
- [x] Repo layout, XcodeGen spec, Info.plist
- [x] Native launcher skeleton (`AppDelegate`, `JVMLauncher`)
- [x] `-Xint` (no-JIT) JVM boot path
- [x] macOS CI that builds an unsigned `.ipa`
- [ ] Supply real `OPENJDK_IOS_URL` and confirm the JVM boots on-device
      (watch device logs for "JVM booted in interpreter-only mode")

## Phase 1 — JVM proven on-device
- [ ] Bundle a real iOS arm64 OpenJDK (Java 21+)
- [ ] Run a trivial `System.out.println` Java class via JNI to confirm the
      interpreter executes bytecode under the no-JIT entitlement set
- [ ] Redirect Java stdout/stderr to the iOS log / an in-app console

## Phase 2 — GL pipeline
- [ ] Link/bundle gl4es + ANGLE; bring up a Metal layer (`CAMetalLayer`)
- [ ] Render a triangle through gl4es → ANGLE → Metal to prove the chain

## Phase 3 — Minecraft bring-up
- [ ] Game-file downloader: parse Mojang version manifest, fetch client jar,
      libraries (filtered for what works), and assets
- [ ] GLFW shim (`src/glfw_shim/`): implement the GLFW symbols LWJGL needs,
      backed by UIKit windowing + touch input → MC key/mouse events
- [ ] Wire `JVMLauncher launchMainClass:` to `net.minecraft.client.main.Main`
- [ ] First frame of the main menu

## Phase 4 — usable launcher
- [ ] Microsoft / Xbox Live auth (device-code flow), token storage in Keychain
- [ ] Version picker, account manager, settings UI
- [ ] On-screen touch controls + gamepad support
- [ ] Memory tuning so iOS doesn't jetsam mid-game

## Known hard problems
- **Performance:** `-Xint` is the ceiling without JIT. Low FPS is expected.
- **Memory:** iOS jetsams hungry apps; large modpacks may be impossible.
- **Mod/loader support:** Forge/Fabric add classpath + native complications.
- **App lifecycle:** the JVM must survive backgrounding or save/quit cleanly.
