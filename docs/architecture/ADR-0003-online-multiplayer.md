# ADR-0003: Online Multiplayer — Host-Authoritative ENet 1v1

**Status:** Accepted (2026-07-08)
**Deciders:** technical direction session (user-approved scope: "Online multiplayer (LAN/internet)")
**Relates to:** ADR-0001 (input/state separation), ADR-0002 (prototype as production base)

## Context

Four Clans / Ninja Clash is a 60 fps couch-PvP arena fighter. The simulation
(`player.gd`, `shuriken.gd`, `blade_wave.gd`) is real-time-clock based
(`Time.get_ticks_msec()`), physics runs through `move_and_slide`, and combat outcomes depend
on frame-order details (clash locks, i-frame windows). ADR-0001 already routed all sim input
through `PlayerInputRouter` snapshots precisely so a network layer could substitute a remote
intent later. The user asked for playable online 1v1 (LAN/internet).

## Decision

**Host-authoritative simulation over ENet (Godot high-level multiplayer), 2 peers, no
client-side prediction.**

- The **host** runs the exact same simulation as a local match. Slot 1 = host's local
  human (merged `p1_*`/`p2_*` devices), slot 2 = the remote guest.
- The **client** sends its local input as two intent bitmasks (held + just-pressed, layout
  `net_codec.gd::ACTIONS`) every physics tick, unreliable-ordered. Just-pressed bits are
  accumulated host-side so a tap between snapshots is never lost.
- The host broadcasts a **world snapshot at 30 Hz** (fighters + shurikens + blade waves;
  formats in `net_codec.gd`, unit-tested). On the client every sim node is a **puppet**:
  `player.gd::_puppet_tick` dead-reckons with snapshot velocity through the real level
  colliders (so floor detection and run/jump poses read correctly) and blends to the
  authoritative position; projectiles are visual ghosts keyed by host-assigned `net_id`.
- **Reliable events**: screen/state changes (`GameState.change_state` relayed with a full
  match bundle — clans, skins, map, MatchConfig, scores, round winner), lobby picks
  (host validates clan conflicts), map-select cursor, combat SFX keys, strip-FX spawns.
- **Roles in menus:** host = P1 and owns Fight Setup, map select, and rematch flow; guest = P2,
  picks its own clan/skin in the shared lobby and can leave at any time. Pause overlays never
  pause the tree online — they mute that machine's gameplay input instead
  (`PlayerInput.suppress_local`).

## Alternatives considered

- **Deterministic lockstep / rollback** — rejected: the sim uses wall-clock time, Godot
  physics and per-frame node iteration order; making it deterministic is a rewrite.
- **Godot `MultiplayerSynchronizer` nodes** — rejected: the game builds everything
  procedurally (no scenes/spawners); explicit snapshot code is smaller and testable.
- **Client-side prediction for the guest's own fighter** — deferred: on LAN the round trip
  is 1–2 frames; over the internet input latency rises with ping. Acceptable for v1;
  prediction+reconciliation is the v2 upgrade path if online play proves popular.

## Consequences

- New autoload `Net` (net.gd) + pure `net_codec.gd`; `ONLINE_MENU` state + `online_menu.gd`;
  ONLINE title button (sprites generated into `sprites/menu/`).
- The guest's view of its own fighter lags by ~1 RTT (fine on LAN; noticeable over WAN).
- **The web (Vercel) build cannot use this** — ENet needs UDP; browsers would need a
  WebSocket/WebRTC peer. Online is desktop-only for now.
- Internet play across NAT requires the host to port-forward UDP 24565 (documented on the
  ONLINE screen as "host address"; no relay/matchmaking service in v1).
- Dev harness: `-- --host` / `-- --join=<ip>` / `-- --online-autotest`
  (`dev_online_autotest.gd`) scripts a full two-instance session; used as the online smoke
  test (lobby sync → arena pick → round → remote-input movement + projectile replication).

## Verification (2026-07-08)

- GUT: 46/46 pass, including `test_net_codec.gd` (intent masks, player snapshot roundtrip
  with clock rebasing, death-transition, shuriken wire layout).
- Two headless instances on localhost: guest driven end-to-end by host state relay
  (TITLE→…→ROUND), remote input moved the guest's fighter 134 px on the host sim, host
  throw appeared as a persistent client puppet shuriken, disconnect returned both sides to
  their menus cleanly.
