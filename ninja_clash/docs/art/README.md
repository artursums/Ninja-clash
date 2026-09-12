# Fighter animation

The original 15 skins and all four clan palettes are retained. Their neutral poses preserve the original visible pixels. Additional poses are baked from the original idle, run, swing and five-pose strips; costumes without extended source strips use their original body poses with breathing, stride, tuck and followthrough offsets.

| Animation | Frames |
| --- | ---: |
| Idle | 8 |
| Run | 12 |
| Rise / fall / wall hold | 6 each |
| Katana swing | 10 |
| Throw | 8 |
| Dodge | 8 |

Each fighter draws one frame from a 576 × 384 atlas. The extra motion is baked offline, so body parts are not separate runtime nodes. Only the selected clan/skin textures need to be loaded; four distinct fighters require about 3.4 MiB of uncompressed RGBA atlas storage.

The original shuriken sprite strips, flight trail and above-head shuriken/katana icons remain in use. The revised katana follows a shared grip position and angle curve, with a blade-aligned trail. Aiming shows preparation; throwing immediately shows release and followthrough. Run and jump/landing dust use eight-frame strips.

Projectile parries are active from 25 to 285 milliseconds, covering 46 pixels in front and 27 pixels above/below the fighter. A swept segment catches blades crossing the reach between physics ticks. Terrain blocks deflection, ownership transfers to the defender, and parrying does not consume a melee charge. Melee damage timing and reach are unchanged.

## Asset maintenance

Original artwork is in `sprites/ninjas/`; `tools/fighter_pose.gd` contains the animation offsets. Bake using a graphics backend after modifying either:

```sh
godot --headless --path ninja_clash --editor --import --quit
godot --path ninja_clash -s res://tools/bake_fighters.gd
godot --headless --path ninja_clash --editor --import --quit
```

Restoration instructions are in `backups/character-design-2026-09-12/README.md` at the repository root. Rejected design studies are archived separately and are not game assets.

```sh
godot --headless --path ninja_clash -s res://tests/integration/fighter_flow.gd
```

The integration check verifies parry direction, timing, terrain obstruction and contact ordering, animation coverage, original neutral pixels for all 60 clan/skin combinations, and original above-head icons.
