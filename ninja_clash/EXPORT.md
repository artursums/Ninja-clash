# Ninja Clash — Export & Store-Readiness Guide

Web exports can be built headlessly using the checked-in preset and installed templates.
Signed native distribution still requires the relevant platform credentials.

## Prerequisites
- Install export templates matching the engine: **Godot 4.6.2** (Editor ▸ Manage Export Templates).
  (Web templates are already installed at `~/Library/Application Support/Godot/export_templates/4.6.2.stable/`.)

## Web (browser rooms — infrastructure setup required)

The **Web preset exists** in `export_presets.cfg` (threads ON, GUT/tests excluded).
Create a Vercel project by importing this repository: select **Other** and keep Root
Directory **./**. The root `vercel.json` installs the pinned Godot 4.6.2 Linux engine
and Web release template, imports the source assets and exports the game. Both official
downloads are SHA-256 verified. The first build downloads about 1.3 GB of build tools;
these tools are temporary and are not served to players. The output is
`build/ninja-clash/public`; `api/rooms.js` exposes the existing room service.
Configure Redis and TURN credentials in the import form or project settings.
See [the complete setup guide](../web/SETUP.ru.md).

Alternatively, from the repository root, build locally and publish using the CLI:
```
cd web
npm ci
npm run export
cd ../build/ninja-clash
npx vercel login
npx vercel deploy --prod
```
The export tool prepares `build/ninja-clash/public/` (game), `api/` and `server/` (room service)
plus the Vercel configuration. Deploy this directory, not just its `public` subdirectory.
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
