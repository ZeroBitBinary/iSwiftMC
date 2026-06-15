# Sideloading iSwiftMC with SideStore (iOS 26.5, from Windows)

> Verify exact steps against the official docs — **https://sidestore.io** — before
> starting. SideStore's bootstrap changes between releases, and iOS 26.x is newer
> than this guide. The *concepts* below are stable; the exact taps may differ.

## Why SideStore (not AltStore / TrollStore) for you
- **TrollStore:** not available on iOS 26.x (tops out ~iOS 17.0). Ruled out.
- **AltStore:** works, but AltServer must stay running on the PC to re-sign.
- **SideStore:** after a **one-time pairing** with a computer, it re-signs apps
  **on-device** over its own local WireGuard loopback VPN. No PC tether afterward.

## Apple-side limits you cannot avoid (free Apple ID)
- Apps expire every **7 days** and must be re-signed.
- Max **3** sideloaded apps at once.
- Use a **throwaway Apple ID**, never your main one.
- A **paid Apple Developer account ($99/yr)** lifts this to **1-year** signing and
  removes the 3-app cap — worth it for a daily-use launcher.

## One-time setup

### 1. Get the IPA
Download `iSwiftMC-unsigned.ipa` — the artifact produced by the GitHub Actions
macOS build (`.github/workflows/build.yml`). SideStore signs it for you; the
unsigned artifact is correct input.

### 2. Generate a pairing file (needs a computer once)
SideStore needs a device **pairing file** to talk to your iPhone for on-device
installs. On Windows this is typically produced via:
- **AltServer for Windows** (apple.com versions of **iTunes + iCloud** installed), or
- SideStore's current recommended pairing tool (check sidestore.io — they have
  moved pairing methods over time, e.g. `Jitterbug`/`StosVPN`-based flows).

The output is a pairing file you import into SideStore on the device.

### 3. Install the SideStore app itself
Bootstrap SideStore onto the iPhone using the method on sidestore.io for your
iOS version (usually via the pairing tool / a one-time computer-assisted install).
Sign in with your **throwaway Apple ID**.

### 4. Trust the certificate
On the iPhone: **Settings → General → VPN & Device Management** → trust your
developer certificate.

### 5. Enable SideStore's VPN
SideStore installs a local **WireGuard** profile (loopback only — it does not
route your real traffic). Approve it; this is what lets it refresh apps on-device.

## Installing iSwiftMC
1. Open **SideStore** on the iPhone.
2. **My Apps → +** (or **Files**) → pick `iSwiftMC-unsigned.ipa`.
3. SideStore signs + installs it. First launch may need another
   **VPN & Device Management** trust tap.

## Keeping it alive (every 7 days)
- Open SideStore periodically; it re-signs on-device (needs network + your Apple ID).
- It can refresh in the background, but don't let all 7 days lapse or the app
  goes dead and must be reinstalled.

## Troubleshooting pointers
- **"Unable to install" / signing fails:** usually the 3-app limit, an expired
  certificate, or anisette/Apple-ID auth. Remove an unused sideloaded app.
- **Pairing lost:** regenerate the pairing file (step 2).
- **App crashes on launch:** that's iSwiftMC itself, not sideloading — check the
  device console for the JVM boot log (see ROADMAP phase 1).
