# Hit SFX — Combat Sound Specification

## 1. Overview

Specification for the combat **hit** sound effects in Ninja Clash: the impacts that
sell every kill, clash, block, and chip of damage in the throw-dodge-retrieve loop.
The game currently routes nearly all combat feedback through a single overloaded
`"hit"` placeholder beep. This doc defines the distinct hit events, their sonic
character, and the per-play randomization needed to make a fast couch-PvP fight feel
crunchy and immediate rather than robotic.

## 2. Player Fantasy

Steel has weight. When your shuriken buries itself in an opponent, you *feel* it land.
When two katanas meet, the room rings and time hitches for a beat (the existing clash
hitstop). Blocks feel firm, not mushy. No two consecutive hits sound mechanically
identical — the ear never catches the loop. The mix stays readable in a chaotic
4-player FFA: the events that matter (kills, clashes) always cut through.

## 3. Detailed Rules

### 3.1 Current state (code-grounded)

Audio is a single autoload (`ninja_clash/audio.gd`):

- Flat `key → AudioStream` dictionary; fire-and-forget `Audio.play(key)` spawns a
  one-shot `AudioStreamPlayer` on the `SFX` bus (`audio.gd:96-104`).
- Placeholder streams are procedural beeps; **a real file at
  `res://audio/sfx/<key>.ogg` (or `.wav`) auto-replaces a beep on boot, no code change**
  (`audio.gd:63-71`). This drop-in path only works for keys that already exist.
- **No pitch or volume randomization** anywhere — every play of a key is identical.

### 3.2 The overload problem

The `"hit"` key is currently triggered by four semantically different events, so they
are sonically indistinguishable:

| Trigger | Location | Real meaning |
|---|---|---|
| `Combat.on_kill()` | `combat.gd:46` | a fighter died (ranged or melee kill) |
| non-lethal `take_damage` | `player.gd:1463` | chip damage, survivor (multi-HP modes) |
| guard meter emptied | `player.gd:448` | guard-break — defender now exposed |
| katana clash clang | `main.gd:646` | two blades met (signature hitstop moment) |

This spec **splits these into distinct keys** and adds light per-play randomization.
Splitting requires a small `audio.gd` change (see §6) beyond the zero-code drop-in path.

### 3.3 Event → SFX mapping (the spec)

Each row is a distinct SFX key. "Rand" = per-play pitch / volume variation applied at
play time. Priority governs voice-stealing under load (see §5.2).

| Key | Trigger (code hook) | Character / feel | Layering | Pitch rand | Vol rand | Priority |
|---|---|---|---|---|---|---|
| `kill_blade` | melee kill via `take_damage`→`_die` (`player.gd:1459-1463`) | meaty crunch + steel slice-through | impact thud + blade *shing* | ±8% | ±2 dB | High — never stolen |
| `kill_shuriken` | ranged kill, `combat.on_kill` (`combat.gd:46`) | wet thunk + metallic *shink* | thunk + zip tail | ±10% | ±2 dB | High — never stolen |
| `katana_clash` ⭐ | `Combat.register_clash` → `main.gd:646` | bright ringing **CLANG** + electric spark; sells the 0.20 s hitstop | ring + crackle | ±5% (keep iconic) | ±1 dB | Highest — ducks others |
| `hit_chip` | non-lethal `take_damage` (`player.gd:1463`) | sharp grunt + light cut (clearly *not* a kill) | cloth/flesh tick | ±10% | ±2 dB | Medium |
| `guard_block` | block on blade/shuriken (`player.gd:1290`, `:1444`) | firm metallic *clink/clank* | clink + micro-scrape | ±12% | ±2 dB | Medium |
| `guard_break` | guard meter emptied (`player.gd:448`) | strained crack → shatter; "you're open" | crack + low whoosh | ±6% | ±1 dB | High (rare) |
| `shuriken_deflect` | parried / protected bounce, no damage (`player.gd:1416`, `:1484`) | light ricochet *tink* | single tink | ±15% | ±3 dB | Low — stealable |
| `shuriken_stick` | shuriken embeds in geometry (`shuriken.gd:259`, `:293`) | dull embed *thud* (distinct from flesh) | thud + surface | ±12% | ±2 dB | Low |
| `stomp_hit` | head-stomp kill (`hit_by_stomp`→`take_damage`, `player.gd:1483`) | heavy downward crunch + small bounce | low thud + pop | ±8% | ±2 dB | High |
| `throw` (existing) | shuriken thrown (`player.gd:1382`) | sharp edged whoosh | whoosh + faint ring | ±10% | ±2 dB | Low |

## 4. Formulas

Per-play randomization, applied when the one-shot player is created:

```
pitch_scale = 1.0 + rand_range(-pitch_var, +pitch_var)      # e.g. pitch_var = 0.08 → ±8%
volume_db   = base_db + rand_range(-vol_var_db, +vol_var_db)  # e.g. vol_var_db = 2.0 → ±2 dB
```

- `pitch_var` and `vol_var_db` are per-key (table §3.3).
- `base_db` defaults to 0.0 (the SFX bus + Settings drive overall level).
- Randomization is uniform; values are clamped to sane ranges (`pitch_scale ∈ [0.5, 2.0]`).

## 5. Edge Cases

1. **Clash de-dupe** — both fighters detect the same clash; `combat.gd:61-65` already
   locks it so `katana_clash` fires exactly once. SFX must not double-trigger.
2. **Kill vs chip** — in 1-HP modes a hit is always a kill (`kill_*`); in multi-HP modes
   a non-fatal hit must use `hit_chip`, only the fatal blow uses `kill_*`. Branch on
   `hp <= 0` (`player.gd:1461`).
3. **Self-hit immunity** — your own shuriken never harms you and gives a pogo, not a hit
   (`player.gd:~1410`); play `shuriken_deflect`/nothing, never a `kill_*`.
4. **Protected bounce** — i-frame/guarded stomp plays a soft blip, not `stomp_hit`
   (`player.gd:1484`).
5. **Voice flood (FFA)** — many simultaneous hits in 4-player. Low-priority keys
   (`shuriken_deflect`, `shuriken_stick`, `throw`) may be dropped/stolen first;
   `kill_*` and `katana_clash` must always play.

## 5.2 Mixing / Priority Notes

- `katana_clash` is the signature moment — give it the most headroom and let it briefly
  duck other SFX during its ring.
- Keep its pitch variation small (±5%) so it stays recognizable as *the* clash sound.
- Kills always audible; positional/ambient ticks are first to be culled under load.

## 6. Dependencies

- **`audio.gd`** — requires a new randomizing play path, e.g.
  `play(key, pitch_var := 0.0, vol_var_db := 0.0)`, applying `pitch_scale` and
  `volume_db` to the spawned `AudioStreamPlayer`. **This is a code change** (the only
  one this spec requires); the new keys then follow the existing drop-in `.ogg` workflow.
- **`audio/sfx/README.md`** — update the key table with the new combat keys.
- **`combat.gd`, `player.gd`, `main.gd`, `shuriken.gd`** — swap the overloaded `"hit"`
  calls for the specific keys above (see §3.3 hooks).
- **`design/gdd/combat.md`** — the source of truth for combat events; keep in sync.
- **`settings_store.gd`** — SFX bus volume already wired; no change.

## 7. Tuning Knobs

- Per-key `pitch_var`, `vol_var_db`, `base_db` (table §3.3) — should live as data, not
  literals. Recommended: a `Dictionary` of per-key params in `audio.gd`, or a small
  `SfxTuning` resource mirroring the project's `PlayerTuning` pattern.
- Clash duck amount + duration.
- Global SFX bus level (already in `Settings`).

## 8. Acceptance Criteria

1. Kills, clashes, blocks, guard-breaks, chip hits, deflects, and sticks are each
   **audibly distinct** — a blindfolded listener can name the event.
2. Ten consecutive identical events (e.g. ten blocks) exhibit **no perceptible
   repetition** thanks to pitch/volume randomization.
3. `katana_clash` reliably cuts through a busy 4-player FFA mix.
4. In multi-HP modes, a non-fatal hit and a fatal hit sound different (`hit_chip` vs
   `kill_*`).
5. Dropping a real `res://audio/sfx/<key>.ogg` replaces a placeholder with **no code
   change** for every key in §3.3.
6. No combat event is silent; no event double-triggers (clash de-dupe holds).
