# Match presentation and selection

The results screen uses the same pixel font, sanctuary backdrop, gold selection frames
and clan portraits as character selection. Portraits resolve the winner's actual clan
and costume, including palette swaps. The between-round banner keeps only the original player/wins lettering.
The HUD shows numeric round wins / match target without portraits, inset from the
upper left and right corners. Four-player matches add a second card inward on each side.
The former mode/debug caption and results-screen controller legend are removed.

## Battle record

The record covers the whole match and clears only on a new match or rematch.
Only the authoritative simulation records events during an active round:

- **Katana strikes**: a swing starts, or a charged blade wave is emitted.
- **Shuriken throws**: a projectile is actually spawned, including infinite-ammo throws.
- **Hits landed**: an opponent accepts damage. Blocks, invulnerability, self-hits and
  duplicate contacts do not count; the lethal hit counts once.
- **Blocks**: a successful guard interception.
- **Eliminations**: an opponent's death credited to that player, excluding suicides.

The reliable state bundle carries these counters before the client shows the results.
Clients cannot add counters, pick rematch actions, or choose the host's next arena.
They retain a visible Leave Match button.

## Input flow

Duel proceeds directly to clan selection. Solo, Spectate and Free For All open a rank
dialog on Continue. Up/Down selects Genin, Chunin or Jonin; confirm accepts it; Back
returns to the mode cards. Clicking a rank accepts it. The dialog blocks clicks behind it.
Clan selection ignores the opening frame so a confirmation cannot carry into that screen,
even when first-time portrait loading outlasts the time-based input lock.

Arena selection uses Up/Down without edge wrapping. Down from the last arena reaches
Fight; Up from Fight or Random reaches the last arena above them. Left/Right moves
along the bottom row in its visible order: Back, Random, Fight. Selecting
an arena moves the active highlight to Fight, while retaining a muted frame around the
selected map. Confirm again to start. Cancel from Fight returns to the selected map.
Mouse users can select the map and then click Fight. Arena counters and previous/next
arrow buttons are omitted.

Random preselects a uniformly random map (including the current one), scrolls a clipped
vertical reel downward for 3.25 seconds, accelerates, brakes, settles with a small
rebound and gold flash, briefly holds the named result, then selects Fight. It never starts a match
by itself. Selection actions are disabled during the roll. The host shares the start
and target reliably with the guest; both render the same reel. Leaving the screen
cancels the animation, without a delayed callback that could change a later screen.

## Verification

```sh
godot --headless --path ninja_clash -s res://tests/integration/menu_flow.gd
godot --path ninja_clash -s res://tests/integration/results_flow.gd
```

The latter exercises keyboard actions, all 16 carousel start/target combinations,
production attack and damage paths, record reset/persistence, every winning slot,
two- and four-player tables, host/client state transfer, and rematch. With a graphics
backend it saves UI captures to `/tmp/menu-polish-*.png` (the showcase table uses
fixture counters). `tools/preview_menu_carousel.gd` captures a 30 FPS reel sequence
in `/tmp/carousel-frames`.
