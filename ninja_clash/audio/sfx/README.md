# SFX — drop-in real audio

The game ships with **procedural placeholder beeps** (generated in `audio.gd`). To replace any of
them with a real sound, drop a file here named exactly `<key>.ogg` (or `.wav`). On boot the Audio
autoload swaps the beep for your file automatically — **no code change needed**.

## Keys (file name → when it plays)
| File | Plays on |
|------|----------|
| `throw.ogg` | shuriken thrown |
| `hit.ogg` | a hit lands |
| `dodge.ogg` | dodge / dash |
| `block.ogg` | guard blocks (blade parry) |
| `round_start.ogg` | round begins |
| `countdown.ogg` | pre-round countdown tick |
| `click.ogg` | menu move |
| `confirm.ogg` | menu confirm |
| `win_1.ogg` · `win_2.ogg` · `win_3.ogg` | victory fanfare (3 ascending notes) |

`.ogg` preferred (smaller). Mono is fine. Keep them short; these are UI/combat SFX, not music.

> Music (per-state tracks) is not wired yet — it belongs with the audio-bus work when real music
> exists. Master volume is already controllable via the `Settings` autoload.
