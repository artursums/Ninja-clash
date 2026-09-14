# Random shuriken perks

Implemented 2026-09-14. Initial balance values; human playtesting should determine any
later changes to durations, spawn frequency or tracking strength.

## Player rules

Touch a capsule after its one-second arrival warning to collect it. A fighter can hold
one perk at a time. The badge beside the fighter shows the kind and remaining special
throws. A perk modifies existing ammunition: it does not refill the stash. Charges are
spent on throws, even with infinite ammunition enabled. Death and round reset clear
both held charges and reversed movement.

| Capsule | Special throws | Effect |
| --- | --- | --- |
| REVERSE | 1 | A damaging hit reverses horizontal movement, including directional dashes, for 3 seconds. Jumping, attacks and aiming retain their controls. Further hits cannot extend the active reversal. The victim sees a countdown. |
| SEEKER | 2 | Locks the nearest living opponent when thrown. Routes around terrain with limited turning speed for up to 2 seconds, then resumes ordinary flight. Does not retarget when that opponent dies. A katana deflection breaks tracking. |
| PHASE SWAP | 1 | Flies straight through terrain. First valid enemy hit exchanges the fighters' positions without damage or inherited momentum. Refuses unsafe destinations inside terrain, another fighter or outside the arena. The projectile vanishes after 6 seconds if it misses. |
| RICOCHET | 2 | Reflects off any terrain surface at the actual impact angle, up to **3 bounces**. Walls, ceilings, floors and platforms all count; the fourth terrain contact sticks. After the first bounce it can hurt its owner. After 3 seconds it becomes harmless, recoverable ammunition. |

Terrain bounce direction is determined by the surface normal. It is not a randomly
chosen angle, and repeated contact with the same surface still consumes a bounce.
Ricochet rings and remaining-bounce marks distinguish a live hazard from an ordinary
spent blade. Its damage stays at one heart.

Existing dodge catches, guards and katana parries remain available against special
blades. Caught ammunition loses its perk. A blade-versus-blade clash ends both perks
and retains the existing harmless spent-blade behavior.

PHASE SWAP can appear only while at least three fighters are alive. If the round falls
to two survivors, any uncollected swap capsule disappears. A charge already earned
can still be thrown.

## Arrival schedule

- First capsule becomes available 6–10 seconds into the active round, preceded by a
  one-second warning. The schedule pauses outside active gameplay.
- 50% of rounds schedule one capsule; 35% schedule a second 8–12 seconds after the
  first; 15% schedule two together, with different types and at least 180 pixels apart.
- Types come from a shuffled bag without replacement, filtered for the living count.
- Capsules use clear standing positions on authored ledges, at least 80 pixels from
  living fighters when the warning begins. If no safe point is available, the event
  retries briefly and is then skipped. A double arrival may become single if only one
  safe location is available.
- An uncollected capsule lasts 8 seconds after its warning. Holding another perk
  prevents collecting it. Shuriken-disabled matches schedule no capsules.

## Simulation and networking

The host owns the random schedule, collection, charges, reversal, tracking, bounces
and swaps. Snapshots carry capsule identities and timers, fighter perk state, projectile
perk state and a teleport revision. Clients snap swapped positions immediately rather
than smoothing the fighter through intervening walls.

Room and peer protocol **4** requires the API and web export to ship together. Players
using an older cached build must reload before creating or joining a room.

Seekers share a cached AStarGrid2D terrain map. A swept collision check remains the
authority for special projectile contacts; navigation cannot let a seeker penetrate
a platform. Bots can pursue reachable capsules and use seekers or phase shots against
opponents behind cover.

## Verification

- `tests/unit/test_perks.gd`: finite charges, reversal axis, shuffle eligibility,
  player/projectile snapshot round trips and reflection normals.
- `tests/integration/perk_flow.gd`: three different surface bounces and fourth-contact
  sticking, owner damage, catches, no reversal stacking, safe swaps through walls,
  seeker routing and expiry, deflection, pickup contention, schedules and cleanup.
- `web/tests/online.spec.mjs`: separate Chrome contexts with 2, 3 and 4 players verify
  that the same capsule identity, type and position reaches every guest over WebRTC.
- `tools/preview_perks.gd`: native visual fixture with all four capsules, held-charge
  badges and a reversed-movement timer; saves `/tmp/ninja-perks-preview.png`.

The automated browser checks use local WebRTC connections. They do not establish WAN
latency or final competitive balance.

Engine references: [AStarGrid2D](https://docs.godotengine.org/en/4.6/classes/class_astargrid2d.html)
and [PhysicsShapeQueryParameters2D](https://docs.godotengine.org/en/4.6/classes/class_physicsshapequeryparameters2d.html).
