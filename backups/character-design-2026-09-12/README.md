# Original character presentation

Snapshot taken before the September 12 character and weapon redesign. The archive contains the original artwork, animation/effect scripts, combat tuning and their scene/menu integration. `manifest.json` records the source revision and SHA-256 checksums.

To inspect safely, extract into a separate directory. To restore the full snapshot, first save your current work, then run from the repository root:

```sh
tar --exclude=ninja_clash/arena_ambience.gd -xzf backups/character-design-2026-09-12/original-characters.tar.gz
godot --headless --path ninja_clash --editor --import --quit
```

Restoring scripts also restores the combat behavior from this snapshot; selectively restore only sprites when comparing artwork. New presentation assets live in their own directory and the original sprite folders remain available.

The command preserves the current arena atmosphere, which follows the compact world bounds. To also return to the earlier 960 × 540 arenas, restore `backups/arena-960x540-2026-09-12.tar.gz` from the repository root before importing.
