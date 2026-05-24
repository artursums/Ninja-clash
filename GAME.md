# Four Clans — Game Overview

> A single-page map of the whole game. For depth, follow the links into
> `design/gdd/`. This document summarizes; the linked GDDs are authoritative.

| | |
|---|---|
| **Genre** | 2D single-screen arena PvP / platform fighter |
| **Players** | 2–4, local couch only (online deferred to v2+) |
| **Platform** | PC (Steam + Itch.io); Steam Deck friendly |
| **Engine** | Godot 4.6 · GDScript · Forward+ · GodotPhysics2D |
| **Monetization** | Premium one-time purchase. No microtransactions, no battle pass. |
| **Scope** | Small — ~3 months to v1 |
| **Status** | Design: MVP complete (8/8 system GDDs approved). Code: vertical-slice prototype built, **pre-playtest**. |

---

## The Pitch

Two to four ninjas hunt each other across stacked platforms on a single screen,
each armed with a stash of **3 plain shurikens** — projectiles you can retrieve
from walls and floors mid-fight to keep the pressure on. One hit kills. Built
for the couch: four controllers, one screen, one clean kill at a time.

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

Full rationale and design tests: [`design/gdd/game-concept.md`](design/gdd/game-concept.md).

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
**MVP = 8 systems, all designed and approved.** Index: [`design/gdd/systems-index.md`](design/gdd/systems-index.md).

| System | Tier | Status | GDD |
|---|---|---|---|
| Game State Manager | MVP | ✅ Approved | [game-state-manager.md](design/gdd/game-state-manager.md) |
| Couch Input | MVP | ✅ Approved | [couch-input.md](design/gdd/couch-input.md) |
| Map | MVP | ✅ Approved | [map.md](design/gdd/map.md) |
| Character Controller | MVP | ✅ Approved | [character-controller.md](design/gdd/character-controller.md) |
| Movement *(hot-zone)* | MVP | ✅ Approved | [movement.md](design/gdd/movement.md) |
| Projectile | MVP | ✅ Approved | [projectile.md](design/gdd/projectile.md) |
| Combat *(hot-zone)* | MVP | ✅ Approved | [combat.md](design/gdd/combat.md) |
| Round Flow | MVP | ✅ Approved | [round-flow.md](design/gdd/round-flow.md) |
| Clan Cosmetics | Vertical Slice | ⬜ Not started | — |
| HUD | Vertical Slice | ⬜ Not started | — |
| Visual FX | Alpha | ⬜ Not started | — |
| Audio | Alpha | ⬜ Not started | — |
| UI Flow | Alpha | ⬜ Not started | — |

**Make-or-break systems:** Movement (owns dodge i-frame timing — the single most consequential
balance lever) and Combat (throw/hit/kill + retrieval economy).

**Deferred:** Accessibility deepening (v1.x), Bot AI (v1.x), Online networking (v2+).

---

## Controls (current prototype)

**Player 1 is controller-only** (DualSense, TowerFall-on-PlayStation layout). **Player 2** plays
on the keyboard (or a second controller). A single DualSense drives P1.

| Action | DualSense | Keyboard (P2) |
|---|---|---|
| Move / aim | D-pad / Left Stick | A D W S |
| Jump (double-jump; wall-jump) | Cross ✕ | Space |
| Throw shuriken | Square ▢ | L |
| Dash-dodge (8-way burst + i-frame catch) | L2 / R2 / Circle ◯ | Right Shift or double-tap A / D |
| Katana (melee swing) | Triangle △ | K |

Hold a vertical direction while throwing to aim up/down. Full mapping + dash/dodge rules:
[`prototypes/movement-and-combat/README.md`](prototypes/movement-and-combat/README.md).
Production target remains **4 controllers with hot-plug**.

---

## Prototype

Location: [`prototypes/movement-and-combat/`](prototypes/movement-and-combat/) — throwaway code, not
production. Full doc + screenshots: [its README](prototypes/movement-and-combat/README.md).

Validates the central hypothesis: *"The throw-dodge-retrieve loop is intrinsically fun in 2-player
local play for 15+ minute sessions."*

It runs the full simulated flow — title → mode select → clan select → map select → match (first-to-5) →
match end — on **1 arena (Sakura Temple)**, with live tuning sliders for the key balance levers,
**pixel-art ninjas and backdrop**, and procedural beep SFX. **Run:** open the folder in Godot 4.6, F5,
pick `Main.tscn`.

A **mode select** offers **P1 vs P2 / P1 vs AI / AI vs AI** with a 3-tier bot (GENIN / CHUNIN / JONIN) —
so you can play a friend, try to beat the AI, or watch an AI-vs-AI demo. *(This is prototype scope; the
design defers Bot AI to v1.x — the bot here is an early experiment for feel, not the shipping AI.)*

> ⚠️ **The prototype has diverged from the design above.** It currently uses a **5-HP health system
> plus a katana melee (3 charges)** instead of the design's **one-hit-kill, no-abilities** rules
> (Pillars 1–2 and 4). This is an open experiment, *not* an approved design change — the GDDs in
> `design/gdd/` remain authoritative until the direction is decided. Reconcile before production.

**Decision gate:** the [`REPORT.md`](prototypes/movement-and-combat/REPORT.md) Result/Metrics/Recommendation
sections are **blank pending a real playtest**. Outcome is PROCEED / PIVOT / KILL — if the loop isn't fun
even with extreme tuning, the project pivots or stops before any production code is written.

---

## Where Things Live

| Path | Contents |
|---|---|
| `design/gdd/` | Game design docs — concept, systems index, per-system GDDs |
| `design/art-bible.md` | Visual direction (pixel-art, ukiyo-e touchstone, palette-swap clans) |
| `design/levels/launch-maps.md` | The 4–6 spec'd launch arenas |
| `prototypes/movement-and-combat/` | Playable vertical-slice prototype (throwaway) |
| `docs/engine-reference/godot/` | Version-pinned Godot 4.6 API reference |
| `src/` | Production game code *(empty — awaiting prototype validation)* |
| `production/` | Sprint / milestone / session-state tracking |

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
