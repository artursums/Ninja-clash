# DEV-005: Charged katana "blade-wave" projectile (hold-to-throw slash) + config toggle

**Status:** 🔵 Backlog   **Priority:** P2   **Area:** gameplay / VFX
**Created:** 2026-05-29
**Depends on:** DEV-001 (config/variants menu + `MatchConfig`), DEV-004 (slash-trail VFX + shuriken-style afterimage trail)

## Idea (raw)
> tuli siuke mõte, et kui character hoiaks ütleme 3 sekundit katana lööki, siis tal võiks
> olla nö löögivise, nagu teistes mängudes on. See sama löögiefekti saba, mis me
> genereerisime peaks lendama aga strictly selles suunas mis oli talle määratud. Kui hitib
> platvormi või seina, siis kaob ära. Selline löök tarbib samuti ühe katanalöögi ning
> hittides võtab ainult ühe südame hp punkti. Tee vastav konfiguratsiooni addition ka
> config menüüsse, kus saab mängu reegleid paika panna. See löök peab olema ka valikuline.
> Aga selle löögi puhul isegi nurjunud pihtasaamine raiska katana attempti. See ei ole
> nagu katana löögiga, et kui ei saa pihta või vastu bloki, siis ei lähe maha. Löögivise
> puhul igal juhul kaob attempt. Ja veendu, et sellel löögilainel on olemas ka effekt, et
> lendaks shurikeni taoliselt varjudega jne sama effektidega

(Translation for context: "Idea: if the character holds the katana strike for, say, 3
seconds, they could do a 'blade-wave throw' like in other games. That same strike-effect
tail we generated should fly off, but STRICTLY in the direction assigned to it. If it
hits a platform or wall, it disappears. This strike also consumes one katana charge and
on hit takes only one heart of HP. Add a corresponding config addition to the config menu
where you set the game rules — this strike must be optional. But for this strike, even a
MISSED hit wastes the katana attempt — it's not like the normal katana strike where a
miss or a block doesn't spend the charge; the blade-wave always consumes the attempt. And
make sure this wave also has an effect — it flies like a shuriken, with shadows/
afterimages, the same effects.")

## Prompt for Claude
> Paste everything below into a fresh Claude Code session to start this task.

### Objective
Add an optional new offensive move to the production game (`ninja_clash/`): a **charged
katana "blade-wave" projectile**. Holding the katana attack input for a few seconds (≈3 s)
releases a slash wave that flies **strictly in the aimed direction**, reusing the
generated katana slash-trail VFX with a shuriken-style afterimage/shadow trail. It travels
until it hits a wall/platform (then disappears), deals **1 HP (one heart)** on hitting a
fighter, and **always consumes one katana charge on release** — even on a miss or a block
(unlike the melee swing, which doesn't spend the charge when it whiffs/clashes). The move
is **off by default and toggleable** in the config/variants menu.

### Context
- **Katana melee (current).** A tap of `input_katana` starts a swing if
  `katana_charges > 0` and off cooldown (`player.gd` ≈ 528:
  `if _pressed(input_katana) and not is_swinging and not is_defending and
  katana_charges > 0 and t >= katana_cooldown_until`). The swing runs for
  `KATANA_SWING_DURATION_S`; charges (`katana_charges`, max `MAX_KATANA`) refill on
  respawn. Per the established rule, a melee charge is NOT wasted on a pure miss or when
  the blades clash/are blocked — the blade-wave deliberately differs.
- **Guard / clash.** Guard (`input_defend`, `is_defending`) plants the blade to block
  front shurikens & strikes; two swings meeting register a clash (`Combat.register_clash`,
  no damage/charge cost). The wave should interact with guard/dodge like other incoming
  attacks (blockable/dodgeable) but still spend the charge regardless.
- **Shuriken projectile (the model for "flies like a shuriken with shadows").**
  `ninja_clash/shuriken.gd` is an `Area2D` with `velocity_v`, a `HITBOX_SIZE` collision,
  `body_entered` → `_on_body_entered` (≈ 218) for player hits / sticking in terrain, and a
  **comet-trail afterimage system**: frames 0-3 spin, frames 4-7 are fading trail
  afterimages (`TRAIL_FRAME_BASE`, `TRAIL_COUNT = 4`, `TRAIL_STRIDE`, sampled from a
  position history; `_update_trail()` ≈ 152). Shurikens also do aim-assist steering toward
  a visible foe — the **blade-wave must NOT steer** (it goes strictly straight in the
  assigned direction). Shurikens stick and are retrievable; the wave instead **vanishes**
  on terrain and is not pickup ammo.
- **Slash VFX.** DEV-004 Deliverable C generates a katana slash-trail sprite/strip on the
  `fx_anim.gd` pipeline — reuse that art as the wave's body visual, combined with the
  shuriken afterimage trail for the "shadows."
- **Aim.** Throws/aim use 8-way direction from `aim_up`/`aim_down` + facing (see the throw
  code and `_throw_aim()` in `player.gd`). The wave's launch direction reuses this so it
  fires "strictly in the direction assigned to it."
- **Config menu.** DEV-001 adds the `MatchConfig` autoload + a Fight Setup/Variants screen
  reached from clan-select; this task adds one more toggle (and any tuning) there.

### Relevant files
- `ninja_clash/player.gd` — katana input/charge logic (≈ 528), swing state
  (`is_swinging`, `swing_start_t`, `KATANA_*`), aim helpers, charge field
  (`katana_charges`), and the FX spawn helpers (≈ 1197/1212) — add the hold-to-charge
  detection, the release→spawn-wave, and the always-spend-charge rule here.
- `ninja_clash/shuriken.gd` — the projectile + afterimage trail to model the wave on
  (consider extracting the trail system into a shared helper rather than duplicating).
- `ninja_clash/combat.gd` — `Combat` autoload (damage/score signals, clash); the wave's
  hit applies 1 damage via the same `take_damage(1, ...)` path used elsewhere.
- `ninja_clash/player_tuning.gd` / `.tres` — add data-driven knobs (charge hold time,
  wave speed, damage, lifetime) — no hardcoded tuning.
- `ninja_clash/sprites/fx/` — the slash-trail art from DEV-004 used as the wave visual.
- The `MatchConfig` autoload + variants screen from **DEV-001** — add the enable toggle.
- A new `ninja_clash/blade_wave.gd` (suggested) — the projectile script (Area2D), sibling
  in spirit to `shuriken.gd`.

### Requirements
1. **Charge → release.** Holding `input_katana` past a threshold (default ≈3 s, a tuning
   knob) and then releasing fires a blade-wave instead of a melee swing. A short tap (or a
   release before the threshold) performs the normal swing exactly as today. Requires
   `katana_charges > 0` to begin charging/fire. Give a clear charge tell (e.g. the slash
   VFX building at the blade / a glow) so the player and opponent can read it.
2. **Strictly directional flight.** The wave launches in the aimed 8-way direction
   (`aim_up`/`aim_down` + facing) and travels in a straight line — **no shuriken-style
   aim-assist steering**.
3. **Terrain = despawn.** On overlapping a wall/platform `StaticBody2D`, the wave
   disappears (no sticking, no pickup). Give it a sane max lifetime/range as a fallback.
4. **Damage.** On hitting a live opposing fighter, deal **1 HP** via the standard
   `take_damage(1, ...)` path (same as a normal hit), then despawn (single-target; not
   piercing, unless tuned otherwise).
5. **Always spends the charge.** Releasing the wave consumes one `katana_charge` at launch
   **regardless of outcome** — miss, terrain despawn, or block all still cost the charge.
   This is the explicit contrast with the melee swing (which doesn't waste a charge on a
   whiff/clash). It may still be blockable/dodgeable for damage, but the charge is gone.
6. **Shuriken-style VFX.** The wave flies with the same afterimage/"shadow" comet trail as
   shurikens (reuse/refactor `shuriken.gd`'s trail), using the DEV-004 slash-trail art as
   the head visual, tinted to the clan color and oriented to the flight direction.
7. **Config toggle (optional move).** Add a **Blade Wave: ON / OFF** entry to the
   DEV-001 config/variants menu via `MatchConfig`, **default OFF** (standard rules
   unchanged). When OFF, holding the katana never produces a wave (normal swing only).
   Surface relevant tuning (hold time, damage) consistently with the other variants.

### Constraints
- Godot 4.6 / GDScript (see `docs/engine-reference/godot/VERSION.md`); cross-check
  `Area2D`/timer/input-hold APIs there.
- Follow CLAUDE.md: ask before writing files, keep all tuning data-driven (hold time,
  speed, damage, lifetime), match conventions in `ninja_clash/` (typed GDScript, the
  group/signal patterns used by `shuriken.gd`).
- Don't break the existing tap-to-swing melee; the charge path must not add input latency
  to a normal swing.
- Bots: the AI (DEV-002) should treat the wave as a tool only if enabled; at minimum the
  wave must not break bot behavior when OFF. (Teaching bots to use it can be folded into
  DEV-002 or deferred.)
- Performance: reuse the shuriken trail/pooling approach; keep within the 60 fps / frame
  budget (technical-preferences.md).
- VERIFY by playing: charge tell shows, wave flies straight in the aimed direction,
  despawns on walls, deals exactly 1 heart, the charge is spent on every release
  (including misses/blocks), and the toggle gates it. Screenshots/clips per
  coding-standards.md; headless parse/import check (`reference_godot_headless_verify`).

### Assumptions
- Charge hold threshold default ≈3 s (tuning knob); released early = normal swing.
- The move is OFF by default in `MatchConfig` (it is an optional rule).
- The wave is blockable by guard and dodgeable via i-frames like other incoming attacks,
  but the charge is consumed regardless of whether the hit lands/blocks.
- The wave is single-hit (despawns on first fighter hit), not piercing, unless a tuning
  knob is later added.
- Movement during the charge is allowed (no root), with a visible charge tell; whether to
  slow/root the charger is a tuning detail left open.
- Launch direction uses the existing 8-way aim; with no directional aim held it fires along
  `facing`.

### Acceptance criteria
- [ ] Holding the katana ≈3 s then releasing fires a blade-wave; a tap still does a normal
      swing with no added latency.
- [ ] The wave flies straight in the aimed 8-way direction with NO aim-assist steering.
- [ ] The wave despawns on hitting a wall/platform and has a max lifetime fallback.
- [ ] A fighter hit by the wave loses exactly 1 heart (1 HP) and the wave despawns.
- [ ] Releasing the wave always spends one katana charge — verified on a clean miss, a
      terrain despawn, AND a blocked hit (contrast: a whiffed/clashed melee swing does
      not).
- [ ] The wave renders with the DEV-004 slash art + shuriken-style afterimage trail,
      tinted to the clan color and oriented to flight.
- [ ] A **Blade Wave ON/OFF** toggle exists in the DEV-001 config menu, default OFF; when
      OFF the move cannot be produced.
- [ ] Tuning (hold time, speed, damage, lifetime) is data-driven; project parses/imports
      headless clean.

### Out of scope
- Teaching the AI to use the wave optimally (coordinate with DEV-002 separately).
- Generating the slash-trail art itself (that is DEV-004 Deliverable C; this task consumes
  it — if it isn't ready, use a placeholder strip).
- New katana mechanics beyond this move (e.g. multi-hit charge tiers, reflect).
- Online/netcode considerations.
