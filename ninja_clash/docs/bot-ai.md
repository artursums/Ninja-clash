# CPU behaviour

The CPU uses the same movement, damage, charge limits and virtual inputs as a human fighter. `player.gd` applies those inputs; `bot_brain.gd` chooses them. Navigation is prepared during the match intro and shared by bots using the same arena and movement tuning.

## Decisions

The controller holds a destination for 0.75–2 seconds, depending on difficulty and a bounded random interval. It samples the opponent periodically and retains an opponent in a crowded fight instead of switching every frame. Movement targets do not track the opponent's X coordinate continuously.

Plans are observe, reposition for a clear shot, pressure, retreat, scavenge and recover. A stationary opponent still gets contested: after several seconds without an attack, the CPU seeks contact. Recovery after melee is a short local disengagement. Empty ammunition prompts reachable pickups, then melee; head-stomps remain a last resort when completely disarmed.

## Platforms

`bot_navigation.gd` builds directed jump, drop and jump/dash connections from the arena's exposed ledges and collision rectangles. Swept fighter bounds account for walls, ceilings, body width and landing clearance. Connections use the movement tuning's actual speed, gravity, jump, fall cap and dash values. Drops have an explicit exit waypoint so the CPU can get around the edge of a solid platform before moving underneath it.

The CPU commits to a traversal, controls its landing, and temporarily excludes a failed connection when interrupted or stuck. Unplanned airborne motion seeks a landing. These routes do not rely on screen wrapping or wall-jump exploits; wrapping and wall contact still recover through normal player physics.

## Combat and difficulty

The tiers change reaction delay, observation cadence, plan duration, aim error, aggression and recovery. They do not change movement speed or damage. Throw direction is locked during a visible aim window and rounded to the nearest of eight directions. Obstructed shots and blocked launch points are rejected.

Defence predicts relative projectile motion, ignores near misses and occluded projectiles, and samples success once per threat. A failed read is not rerolled every frame. Blocks persist briefly; dodges require a viable direction and the actual dash charge. Blade waves are treated as blockable/dodgeable threats, not parryable shurikens. Melee defence also has reaction latency. Optional charged-wave attacks currently use normal quick katana swings on the CPU.

Balance lives in `bot_tuning.gd` (three values per field: Genin, Chunin, Jonin). `bot_tuning.tres` loads these defaults and may override individual fields in the editor. Decision tests can seed each brain's random generator without altering global randomness.

## Validation

From the repository root, replacing `Godot` with the installed executable:

```sh
Godot --headless --path ninja_clash -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json --log-file /tmp/bot-unit.log
Godot --headless --path ninja_clash -s res://tests/integration/bot_flow.gd --log-file /tmp/bot-flow.log
Godot --headless --path ninja_clash -s res://tests/integration/bot_playtest.gd --log-file /tmp/bot-playtest.log
```

`bot_flow.gd` verifies all ledge pairs on all four maps, checks each selected connection against Godot's real body collisions, and covers committed destinations, blocked throws, reaction latency, persistent mistakes, guard duration, blade waves and respawn reset. `bot_playtest.gd` runs eight real-time pursuit scenarios (above and below a stationary opponent on every map). Without `--headless`, it also writes game screenshots to `/tmp/bot-playtest-*.png`.

These regressions protect navigation and decision rules; human playtesting is still needed to judge fun and adjust difficulty.
