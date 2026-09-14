# Online party validation — 2026-09-14

Implemented locally: 2–4 online humans; required session names; one shared invitation;
four-seat Ready/Start lobby; synchronized rules and map; named HUD/results; rematch
readiness; replacement guests; atomic capacity and match-start admission.

| Check | Result |
| --- | --- |
| Node room/API tests, including real Redis CAS | 16 passed |
| Godot GUT unit tests | 63 passed |
| Online scene integration | 91 checks, 0 failures |
| Existing menu integration | 265 checks, 0 failures |
| Two native ENet processes | Both exited successfully; remote fighter moved 48 px |
| Chrome direct WebRTC | 2, 3 and 4-player matches passed |
| Browser name/session flow | Passed: blank name blocked, failed join retains name, leaving clears it |
| Four Chrome contexts with local TURN forced | Passed; selected candidate reported relay |
| Final two-player HUD/rules/input regression | Passed |
| Release Web export | Succeeded; game and protocol-3 room API packaged together |
| Normal Godot boot/exit and diff whitespace checks | Passed |

Browser checks used real keyboard/mouse input and read-only debug telemetry. They covered
all guest inputs, replicated projectiles, explicit Start, readiness invalidation, a fifth
player being rejected, a guest leaving, a replacement joining with the same invitation,
and host loss. The final release omits debug telemetry.

Scene integration runners report a resource teardown warning at exit, despite zero failed
checks. A normal game boot and exit completed without script errors or that warning.
The export tool also reports an ObjectDB teardown warning after successful packaging.

These are local tests. Cross-network latency, production Vercel/Redis/Cloudflare and
other browsers still need deployment verification. No production deployment was made.
The game export and room API must be deployed together because signaling uses protocol 3.

Reproduce from the repository root:

```sh
node --test web/tests/*.test.mjs
/Applications/Godot.app/Contents/MacOS/Godot --headless --path ninja_clash -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --path ninja_clash -s res://tests/integration/online_flow.gd
node web/tools/export.mjs --debug
npm --prefix web run test:browser -- online.spec.mjs
NINJA_TEST_TURN=1 npm --prefix web run test:browser -- online.spec.mjs --grep 'four browsers play with TURN'
node web/tools/export.mjs
```

The TURN run requires the locally installed `turnserver` (coturn).
