# Round clock

Implemented 2026-09-14. The default is **60 seconds**. MATCH SETUP → ROUND TIME changes
the duration in 30-second steps up to five minutes; OFF disables it. The value is saved
with the existing match rules and shared by the online host. Reset restores 60 seconds.

The centered clock starts when the active round starts, not during the intro or
countdown. Offline pause freezes it. An online player's pause menu does not stop the
shared match. The final 15 seconds turn gold and the final five turn red. Overtime is
red throughout. The four-player score layout leaves the clock a clear central space.

At zero, a sole highest-health survivor wins one round point without kill credit. If
several players tie for the most health, only those leaders continue, each with one
heart, for a **20-second sudden death**. Lower-health survivors are eliminated without
kill credit. Last fighter standing wins as usual. If multiple fighters survive the
extra 20 seconds, the round is a draw with no points; the next round starts normally.
No blade temper or arena-heating mechanic is enabled by this clock.

The host alone resolves expiry and scoring. Clients receive remaining time and phase
in world snapshots and reliable state transitions, interpolating only the display.
An expired client display cannot award a point or start overtime. Protocol 5 prevents
older games with incompatible round rules from joining. Timer and ammo tests cover
disabled timing, single expiry, ties, draws, independent perk ammunition and snapshots.

Engine behavior checked against [Godot Node processing](https://docs.godotengine.org/en/4.6/classes/class_node.html)
and [CanvasItem drawing](https://docs.godotengine.org/en/4.6/classes/class_canvasitem.html).
