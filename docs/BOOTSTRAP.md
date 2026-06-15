# Bootstrap runbook: from this repo to an installed app

A literal checklist to get the first installable file onto your iPhone. Steps
marked **(only you)** need a Mac-backed runner, a GitHub login, or your device —
they cannot be done on the Windows machine where this was authored.

## 0. Prerequisites
- A GitHub account **(only you)**.
- SideStore set up on the iPhone. See `docs/SIDELOADING.md`. **(only you)**

> The Java runtime is **already handled** — `fetch-deps.sh` auto-extracts an
> iOS arm64 Java 17 runtime from PojavLauncher's public IPA. No JRE to obtain,
> build, or host. (Override with `OPENJDK_IOS_URL` only if you want a different JDK.)

## 1. Push the repo to GitHub
```bash
cd iSwiftMC
git init && git add . && git commit -m "iSwiftMC scaffold"
git branch -M main
git remote add origin https://github.com/<you>/iSwiftMC.git
git push -u origin main
```

## 2. (Optional) secrets
**You can skip this entirely.** With no secrets set, the build auto-fetches Java
17 and skips the GL libs (not needed until rendering). Only add secrets if you
want overrides:
- `OPENJDK_IOS_URL` — a different iOS arm64 Zero JRE tarball.
- `GL4ES_IOS_URL`, `ANGLE_IOS_URL` — once you reach rendering (phase 2).

## 3. Trigger the build
Push to `main` (or GitHub → Actions → "Build iSwiftMC" → Run workflow). The macOS
runner will:
1. `fetch-deps.sh` → download + verify the JRE and GL libs.
2. `bootstrap/build.sh` → build the game-file installer jar into the bundle.
3. `xcodegen` + `xcodebuild` → compile.
4. Package and upload **`iSwiftMC-unsigned.ipa`** as an artifact.

## 4. Download the IPA
Actions → the run → Artifacts → `iSwiftMC-unsigned-ipa`. **(only you)**

## 5. Sideload via SideStore  **(only you)**
SideStore → My Apps → + → pick the IPA. See `docs/SIDELOADING.md`.

## 6. Verify the JVM boots
Watch the device console (Console.app via a Mac, or an on-device log viewer) for:
```
[iSwiftMC] JVM booted in interpreter-only (-Xint) mode.
```
That confirms the no-JIT runtime works on real hardware — the foundation for
everything in `docs/ROADMAP.md`.

---

### Reality check on where this gets you
After step 6 you have an installable app that boots a Java 17 interpreter on iOS
and can download Minecraft's files. It does **not** render Minecraft yet — the
GLFW shim, GL→Metal pipeline, auth, and input (ROADMAP phases 2–4) are the
remaining, larger effort. This runbook delivers the proven foundation, not a
playable game.
