# Ninja Clash — Export & Store-Readiness Guide

Export presets and signed builds are created in the **Godot editor** (Project ▸ Export), because
they need the platform **export templates** installed and (for shipping) **code signing** — neither
of which can be scripted headless here. This guide is the checklist; the owner runs the editor steps.

## Prerequisites
- Install export templates matching the engine: **Godot 4.6.2** (Editor ▸ Manage Export Templates).
  (Web templates are already installed at `~/Library/Application Support/Godot/export_templates/4.6.2.stable/`.)

## Web (LIVE — friend-testable build)

The **Web preset exists** in `export_presets.cfg` (threads ON, GUT/tests excluded) and the game
is deployed on Vercel: **https://ninja-clash.vercel.app**

Rebuild + redeploy after changes:
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path ninja_clash \
    --export-release "Web" ../build/ninja-clash/index.html
cd build/ninja-clash && npx vercel deploy --prod --yes
```
`build/ninja-clash/vercel.json` ships the `Cross-Origin-Opener-Policy` /
`Cross-Origin-Embedder-Policy` headers Godot 4 web builds need for SharedArrayBuffer —
without them the game will not boot in the browser. Gamepads work via the browser
Gamepad API (press a button once so the browser exposes the pad).

## Presets to create (Project ▸ Export ▸ Add…)

| Platform | Preset notes |
|----------|--------------|
| **macOS** | App bundle. For distribution outside the App Store you'll need an Apple Developer ID + notarization. For local testing, an unsigned `.app`/`.zip` is fine. |
| **Windows Desktop** | `.exe`. Optionally set the icon (`.ico`) + file metadata. |
| **Linux** | `.x86_64` binary. |
| **(later) Steam Deck** | Linux export runs on Deck. Note the 1280×800 (16:10) display letterboxes the 4:3-ish playfield — accepted for v1 (see Map GDD Open Questions). |

For each preset: set **Application ▸ Icon** to `res://icon.svg` (placeholder — replace with final art),
and fill product name/version under Application.

## Settings persistence (done)
`SettingsStore` (autoload `Settings`) persists audio volume + fullscreen to `user://settings.cfg`
and applies them on boot. A settings menu (UI polish stream) will bind to it. No other save data
in v1 (no meta-progression, per the concept).

## Still owner-sourced (cannot be done in-repo)
- Final **icon** art (current `icon.svg` is the placeholder).
- **Steam page** + app ID + store assets (capsule images, screenshots, trailer).
- **Code signing / notarization** credentials (Apple Developer ID, etc.).
- Running the actual **export** + uploading builds.

## Quick local export (smoke test, once templates are installed)
```
# From the project dir, headless export (preset must exist in export_presets.cfg first):
godot --headless --export-debug "macOS" build/NinjaClash.app
```
