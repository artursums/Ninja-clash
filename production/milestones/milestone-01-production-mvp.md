# Milestone 01 — Ninja Clash v1 (production from prototype base)

> **Status**: In Progress
> **Re-scoped**: 2026-05-26 per [ADR-0002](../../docs/architecture/ADR-0002-prototype-as-production-base.md)
> **Game**: `ninja_clash/` (the promoted prototype) · **Engine**: Godot 4.6

> **History note:** this milestone originally scoped a *from-scratch rewrite in `src/`* of 8
> designed systems. Per ADR-0002 we pivoted: the prototype is a validated, nearly-complete game,
> so we **adopt it as the production base and harden it** instead of rebuilding. The from-scratch
> rewrite (Sprints 1–2) is archived in `archive/src-rewrite/` as reference.

## Goal
Take the validated prototype (`ninja_clash`) to a **shippable, maintainable** couch-PvP game —
quality code where it matters, online (v2) kept viable, real content, store-ready — without
regressing the fun that's already there.

## Three work streams

### 1. Hardening (quality + online)
- [x] **Input/state separation** — sim reads `PlayerInput` intent, not the device (ADR-0001 pattern). Online v2 stays viable. *(done — commit 57e8551)*
- [ ] **Data-driven tuning** — extract hardcoded values (gravity, i-frames, speeds, …) into config Resources, so balance is editable + testable.
- [ ] **GUT tests on the core math** — dodge i-frame window, shuriken physics/recoverability, combat resolution. (Harness now runs in `ninja_clash`; 5 tests so far.)
- [ ] Menu input through the intent layer (lower priority — UI nav, not the replicated sim).

### 2. Store-readiness
- [x] **Save/persistence** — `SettingsStore` (autoload `Settings`) persists audio volume + fullscreen to `user://settings.cfg`, applied on boot. 3 GUT tests. *(A settings menu binds to it in the UI-polish stream.)*
- [~] **Export presets** — guide written (`ninja_clash/EXPORT.md`); the actual presets + signed builds are created by the owner in the editor (needs export templates + signing).
- [ ] Icon (placeholder `icon.svg` wired), store page assets, screenshots/trailer — **owner-sourced**.

### 3. Content / polish
- [ ] **Audio** — real SFX + music replacing the synthesized beeps (system can be built; final audio files owner-sourced).
- [ ] Menu / title polish.
- [ ] Final art pass (generated pixel-art → finished; owner-sourced).

## Exit criteria (shippable v1)
- [ ] A real exported build runs on the target platforms at 60 fps.
- [ ] Core feel/combat math covered by GUT tests; no S1/S2 bugs.
- [ ] Tuning is data-driven (no balance values hardcoded in logic).
- [ ] Input is intent-driven (online-viable); save/settings persist.
- [ ] Real audio + finished art + polished menus.
- [ ] Store page + assets ready.

## What carries over from the rewrite (reference, not re-run)
The archived `src/` work + the GDDs + ADR-0001 are the **hardening guide** — they define the clean
patterns (input/state separation ✅, data-driven config, DI/testability) we now apply to the
prototype rather than rebuild.

## Sprints
| Sprint | Focus | Status |
|--------|-------|--------|
| [Sprint 1](../sprints/sprint-01.md) | *(superseded)* from-scratch Foundation rewrite (GSM, Couch Input) | Archived — see ADR-0002 |
| [Sprint 2](../sprints/sprint-02.md) | *(superseded)* from-scratch Map / Character Controller / Movement | Archived — see ADR-0002 |
| [Sprint 3](../sprints/sprint-03.md) | **Ninja Clash hardening** (input/state ✅ → config + tests) | Active |
| Sprint 4 (planned) | Store-readiness (export, save, icon) | — |
| Sprint 5 (planned) | Content/polish (audio, menus, art) | — |
