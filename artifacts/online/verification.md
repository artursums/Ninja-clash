# Browser multiplayer verification — September 12, 2026

This report records the initial browser-room implementation. At that milestone,
invitation rooms, WebRTC, temporary TURN credentials and Vercel export support were
implemented; cloud accounts and the first public deployment were still pending.

## Results at that milestone

| Check | Result |
|---|---|
| GUT unit tests | 57 passed |
| Menu integration | 261 checks, no failures |
| Node room/API/credential tests | 10 passed, including real Redis |
| Chrome, separate contexts | Direct WebRTC, forced TURN, invalid/closed invitation scenarios passed |
| Native ENet | Host and guest exited successfully; remote input moved the guest 48 pixels and replicated a host shuriken |
| Release export | Two browsers reached ROUND through TURN; invitation copying and absence of debug telemetry checked |

Browser scenarios covered lobby-to-round transitions, remote input, projectile
replication and return to the menu after the host closed. Forced TURN tests configured
`iceTransportPolicy: relay` on both sides and inspected the selected candidates with
`RTCPeerConnection.getStats()`.

[Release result](release-check.json) · [Room](room.png) · [Relayed match](release-turn-round.png)

## Scope and limitations

Checks ran on one Mac with Chrome, Godot 4.6.2, a temporary loopback coturn instance and
a local room service. Redis tests used real Redis through a REST adapter. Cloudflare's
credential response was mocked; the actual Cloudflare service and published Vercel
Function were not covered by those initial checks.

Remote usability still required deployment, real Redis/TURN credentials and a match
across separate networks. Client prediction and match recovery were not implemented.
Some headless fixtures reported resources still in use at shutdown; the warning
predated browser-room support.

## GitHub import verification

The release build ran from tracked sources on macOS and Linux amd64 / Node 22 in Docker
with two CPUs and 4 GB of memory. The Linux check downloaded Godot 4.6.2 and its templates,
verified SHA-256 hashes, imported assets and exported successfully.

The minimal Debian image lacked fontconfig and system CA certificates. Godot reported
unavailable system fonts and TLS during import, but export completed without GDScript
errors. This image was not an exact reproduction of Vercel's build environment.

Chrome opened that Linux release, created a room with HTTP 200, confirmed cross-origin
isolation and reported no script/page errors. [Room screenshot](linux-release-room.png).
The root API returned 405 for GET; all ten server tests passed.

## Fixes after the first public deployment

The original `levels` exclusion in `.vercelignore` also excluded arena assets. It was
changed to `/levels/` so only the root reference directory is excluded.

Godot 4.6.2 Sample playback produced silent output through separate Music/SFX buses,
consistent with [Godot issue #119026](https://github.com/godotengine/godot/issues/119026).
Web playback now uses Stream mode. The build rejects GDScript errors even when Godot
returns exit code zero.

The filtered release export had no script errors and produced a music peak near 0.77
after interaction. A browser test confirmed that muting Music silences the track while
menu sound effects remain audible. Server/deployment tests passed 12/12 and the audio
browser test passed 1/1.

Current deployment instructions: [hosting guide](../../web/SETUP.md).
