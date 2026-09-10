# Four Clans — Game Overview

> A single-page map of the whole game — the **design vision** and how the shipped build
> relates to it. For depth, follow the links into `docs/gdd/`.
>
> Where design and implementation diverge, this document says so explicitly rather than
> describing a game that does not exist. For what the build actually does today, see
> [`ninja_clash/README.md`](../README.md).

| | |
|---|---|
| **Genre** | 2D single-screen arena PvP / platform fighter |
| **Players** | 1–4 local couch · 1v1 online (LAN/internet, shipped — see ADR-0003) |
| **Platform** | PC (Steam + Itch.io); Steam Deck friendly |
| **Engine** | Godot 4.6 · GDScript · Forward+ · GodotPhysics2D |
| **Monetization** | Premium one-time purchase. No microtransactions, no battle pass. |
| **Scope** | Small — ~3 months to v1 |
| **Status** | **Playable and shipped** — web build live, 4 arenas, 4 clans, 15 skins, bots, online 1v1, 46 unit tests. Design docs below are the original vision; divergences are noted inline. |

---

## The Pitch

Two to four ninjas hunt each other across stacked platforms on a single screen,
each armed with a stash of **3 plain shurikens** — projectiles you can retrieve
from walls and floors mid-fight to keep the pressure on. One hit kills.† Built
for the couch: four controllers, one screen, one clean kill at a time.

> † *The shipped build runs on 5 HP with a katana — see [Design vs. the shipped build](#design-vs-the-shipped-build).
> The one-hit ruleset remains selectable in the Fight Setup screen.*

**Core fantasy: restraint as power.** No power-ups, no character abilities, no
weapon variants. The four clans (Shadow, Storm, Frost, Fire) differ only in
costume color and emblem — they are *mechanically identical*. Every win belongs
to player skill alone.

Closest comparables: **TowerFall Ascension**, **Duck Game**, **Lethal League**,
**Stick Fight**. Four Clans bets the whole product on a single deeply-tuned
shuriken loop instead of weapon variety.

---

## Design Pillars

1. **Restraint over Spectacle** — every action is small, every kill clean. Whisper, don't scream.
2. **Fairness Is Sacred** — all players share identical tools; differentiation is cosmetic only.
3. **The Couch Is the Game** — designed for co-located play; reject anything that only makes sense online.
4. **Every Shuriken Matters** — the 3-shuriken stash + retrieval economy is the soul of the game.
5. **Game-Feel First** — polish the verbs (dodge, throw, wall-jump) before adding nouns (maps, modes).

**Not this game:** character abilities, asymmetric balance, online (v1), meta-progression/XP/unlocks,
weapon variants or power-ups, single-player campaign.

Full rationale and design tests: [`docs/gdd/game-concept.md`](gdd/game-concept.md).

---

## Core Loop

- **Moment-to-moment (~30 s):** stalk → throw → dodge incoming → retrieve from wall/floor → reposition. Every throw is a committed resource and an exposed position; retrieval is the recovery beat.
- **Round (~30–60 s):** spawn with 3 shurikens → fight → death is permanent for the round → last player standing wins the round.
- **Match (~15–45 min):** first to **N round wins** (launch default N = 10).
- **Progression: none.** All growth is skill-internal. This is a session game, not a service game — the friend group is the progression system.

---

## Verbs & Rules

| Verb | Notes |
|---|---|
| **Move** | walk, jump, double-jump |
| **Dodge** | dash with invincibility i-frames; **auto-catches** incoming shurikens during i-frames (TowerFall parity) |
| **Wall** | wall-slide, wall-jump |
| **Throw** | spend 1 of 3 shurikens; one hit to any body part is an instant kill |
| **Retrieve** | pick up shurikens stuck in walls / lying on floors (max carry 3) |

Key locked values: stash = **3** (Pillar 4); throw velocity ≈ **200 px/s**; respawn delay **3.0 s**;
pickup radius **12 px**; shurikens stick **permanently until retrieved**. Every map *must* guarantee
100% projectile recoverability. See per-system Tuning Knobs for the full table.

---

## Systems (13 total)

Designed in dependency order: Foundation → Core → Feature → Presentation → Meta.
**MVP = 8 systems, all designed and approved.** Index: [`docs/gdd/systems-index.md`](gdd/systems-index.md).

| System | Tier | Status | GDD |
|---|---|---|---|
| Game State Manager | MVP | ✅ Approved | [game-state-manager.md](gdd/game-state-manager.md) |
| Couch Input | MVP | ✅ Approved | [couch-input.md](gdd/couch-input.md) |
| Map | MVP | ✅ Approved | [map.md](gdd/map.md) |
| Character Controller | MVP | ✅ Approved | [character-controller.md](gdd/character-controller.md) |
| Movement *(hot-zone)* | MVP | ✅ Approved | [movement.md](gdd/movement.md) |
| Projectile | MVP | ✅ Approved | [projectile.md](gdd/projectile.md) |
| Combat *(hot-zone)* | MVP | ✅ Approved | [combat.md](gdd/combat.md) |
| Round Flow | MVP | ✅ Approved | [round-flow.md](gdd/round-flow.md) |
| Clan Cosmetics | Vertical Slice | ⬜ Not started | — |
| HUD | Vertical Slice | ⬜ Not started | — |
| Visual FX | Alpha | ⬜ Not started | — |
| Audio | Alpha | ⬜ Not started | — |
| UI Flow | Alpha | ⬜ Not started | — |

**Make-or-break systems:** Movement (owns dodge i-frame timing — the single most consequential
balance lever) and Combat (throw/hit/kill + retrieval economy).

**Deferred at design time, since shipped:** Bot AI (3 tiers) and online 1v1 both landed
ahead of the original plan. **Still deferred:** accessibility deepening, a real SFX pass,
and Steam/Itch store presence.

---

## Controls

Two keyboard schemes (WASD for P1, numpad for P2) plus up to four gamepads with hot-plug,
on a TowerFall-on-PlayStation layout. Rather than duplicate the mapping here and let it rot,
the authoritative table lives with the code: **[`ninja_clash/README.md` ▸ Controls](../README.md#controls)**.

Bindings are constructed at runtime in `main.gd::_setup_input_map()`, which is also what
lets gamepad assignment be re-derived whenever a pad connects or disconnects.

---

## Design vs. the shipped build

The prototype that tested this design was **promoted to the production codebase** rather
than rewritten — the reasoning is in
[ADR-0002](architecture/ADR-0002-prototype-as-production-base.md). It has since grown
well past prototype scope: 4 arenas, 4 clans, 15 skins, a bot with 3 difficulty tiers, a
Fight Setup variants screen, a pause/settings menu, a tutorial overlay, licensed music and
host-authoritative online 1v1.

Two deliberate departures from the design above are worth stating plainly, because the GDDs
still describe the original rules:

| Design says | Build does | Status |
|---|---|---|
| **One hit kills**, no abilities (Pillars 1–2, 4) | **5 HP**, katana with 3 charges, holdable guard | **Accepted.** Chosen during hands-on iteration — the lethality rule changed, the throw–dodge–retrieve loop it protected did not. The Fight Setup screen can restore 1 HP and disable the katana, so the original ruleset is still playable. |
| **Local couch only**, online at v2+ | **Online 1v1 shipped** | **Accepted.** The ADR-0001 input/state split made it a feed-swap rather than a rewrite; see [ADR-0003](architecture/ADR-0003-online-multiplayer.md). |

The per-system GDDs in `docs/gdd/` were written before these decisions and have not been
retrofitted. They are accurate as design intent and as a record of the reasoning; where they
conflict with the table above, the build wins.

**Decision gate — closed.** The PROCEED verdict and its honest caveats (no formal
multi-tester playtest was ever run) are recorded in [`REPORT.md`](../REPORT.md).

---

## Roadmap

| Tier | Content | Features | Cumulative |
|---|---|---|---|
| **MVP** | 1 map, placeholder art | Core loop, 2 players | ~2–3 wk |
| **Vertical Slice** | 1 polished map | + 4 players, scoring, clans | ~3–4 wk |
| **Alpha** | 4 maps | + menus, first audio pass | ~4–6 wk |
| **v1 Launch** | 4–6 maps, full art + audio | All systems polished; Steam + Itch | ~10–14 wk |
| **v1.x** | + bot/practice mode | + bot AI, accessibility deepening | TBD |
| **v2+** | + online | Networking, possibly consoles | TBD |

**Top risk:** game-feel *is* the product. If dodge / throw / wall-jump / retrieval don't feel sublime,
no content or polish saves the game — which is exactly why the prototype playtest gates everything downstream.
