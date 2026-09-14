# Ninja Clash · Four Clans

A single-screen arena fighter built with **Godot 4.6.2 and GDScript**. Fight with
shurikens and a katana, catch incoming blades during a dodge, and compete for the
last ninja standing. Play against the CPU, share a keyboard and controllers, or
invite up to three friends through the browser.

**[Play in your browser](https://ninja-clash-ffay.vercel.app/)** ·
[Architecture](ninja_clash/docs/architecture/README.md) ·
[Controls and mechanics](ninja_clash/README.md) · [Hosting guide](web/SETUP.md)

![Arena gameplay](ninja_clash/screenshots/04_gameplay.png)

## What is implemented

- Four arenas, four clans and fifteen character styles.
- Local duels, solo matches against three CPU difficulty levels, and four-player free-for-all.
- Browser rooms for 2–4 players: invitations, character selection, shared rules and ready checks.
- Four collectible shuriken perks with independent ammunition, distinct icons and authored spawn locations.
- A configurable round clock, health-based timeout resolution and bounded sudden death.
- Keyboard and controller navigation, hot-plugged controllers, music and separate sound-effect controls.

## Technical overview

| Area | Implementation |
|---|---|
| Game | Godot 4.6.2, GDScript, 2D physics, 800 × 450 interface |
| Input | Per-tick intent snapshots shared by local input, bots and remote players |
| Multiplayer | Host-authoritative simulation, 30 Hz world snapshots, client interpolation |
| Transports | WebRTC for browsers; ENet for native builds |
| Room service | Node.js 22, Vercel Functions, Redis over REST, temporary TURN credentials |
| Verification | GUT unit tests, native integration fixtures, Node tests and Playwright browser tests |

The room service coordinates connections; combat runs on the host. Client movement
is interpolated rather than predicted, so connection latency affects guest controls.
This is a small-session game, without matchmaking, accounts or host migration.

## A guided code review

| Start here | What to look for |
|---|---|
| [main.gd](ninja_clash/main.gd) | Scene composition, match setup and round transitions |
| [player.gd](ninja_clash/player.gd) | Fighter simulation and combat state |
| [fighter_presentation.gd](ninja_clash/fighter_presentation.gd) | Animation, inventory indicators, aiming reticle and effects |
| [input_bindings.gd](ninja_clash/input_bindings.gd) / [player_input_router.gd](ninja_clash/player_input_router.gd) | Device assignment separated from simulation intent |
| [bot_brain.gd](ninja_clash/bot_brain.gd) / [bot_navigation.gd](ninja_clash/bot_navigation.gd) | Combat decisions and platform traversal |
| [net.gd](ninja_clash/net.gd) / [net_codec.gd](ninja_clash/net_codec.gd) | Session authority, replication and wire-format packing |
| [rooms.mjs](web/server/rooms.mjs) | Room lifecycle, membership validation and signaling |
| [tests](ninja_clash/tests) / [browser tests](web/tests) | Behavior checks across simulation, menus and real WebRTC sessions |

## Run locally

Install **Godot 4.6.2**, import `ninja_clash/project.godot`, and press **F5**.
The native game does not require Node.js, Redis or cloud accounts.

For a browser build, install Node.js 22 and the matching Godot export templates:

```sh
cd web
npm ci
npm run export -- --debug
npm run dev
```

Open `http://127.0.0.1:8787`. Local rooms use an in-memory store. Remote internet
play needs the Redis and TURN configuration described in the [hosting guide](web/SETUP.md).
The export tool locates Godot at its standard macOS application path; on other
systems use `godot` in PATH or set the `GODOT` environment variable.

## Run checks

From the repository root, with `godot` in PATH:

```sh
godot --headless --editor --path ninja_clash --import
godot --headless --path ninja_clash -s res://addons/gut/gut_cmdln.gd
godot --headless --path ninja_clash -s res://tests/integration/menu_flow.gd
godot --headless --path ninja_clash -s res://tests/integration/round_clock_flow.gd
npm --prefix web test
```

For browser checks, install Chrome and export a debug build first:

```sh
cd web
npm run export -- --debug
npm run test:browser
```

The browser suite drives the actual Godot canvas and WebRTC connections. TURN tests
need a local `coturn` installation; Redis integration tests need `redis-server`.
Those checks report a skip when their optional dependencies are absent. Export a
release build with `npm run export` before publishing.

## Design and limitations

[Architecture](ninja_clash/docs/architecture/README.md) describes the current component
boundaries. [Design documents](ninja_clash/docs/gdd/) explain individual mechanics;
older milestone reports are historical snapshots, not current feature specifications.

Combat and movement still share a fighter simulation, while rendering, bot decisions,
input routing and network encoding have separate owners. Tests cover reproducible
behavior; balance and the feel of remote play still need human playtesting across
real networks and devices.

## License

The [MIT license](LICENSE) covers the code. Bundled music is reserved and is not
included in the MIT grant; its presence in this repository does not grant permission
to redistribute or resell the tracks. Dependency licenses remain with their packages.
