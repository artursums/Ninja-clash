# ADR-0005: Two to four online humans, session names and explicit Ready/Start

Date: 2026-09-14. Extends ADR-0003 and ADR-0004.

## Product flow

Online Play first asks for a required player name (trimmed, maximum 16 characters).
The name lives in memory, survives rematches and connection failures, and is cleared
when the player deliberately leaves multiplayer or closes the game. Invitation links
survive the name step. Names appear on player cards, the HUD and the results screen;
slot labels and the local-player/host badges distinguish duplicate names.

Creating a room opens a four-seat lobby immediately. One invitation admits up to three
guests. Each player chooses a clan and skin and toggles Ready. The host chooses the arena
and shared rules. Arena/rule changes invalidate readiness. The host's explicit Start
requires 2–4 participants and every participant ready; empty seats are optional. The
host may wait for another friend even when everyone currently present is ready.

No target player count is configured in the rules. The participant roster is frozen
at Start. Late joining, spectators, mixed local/online players, host migration and
automatic reconnect are outside this change. A guest leaving an active match returns
the remaining players to the lobby with readiness cleared; it does not award an
artificial win. A host leaving ends the session. Rematches also go through the lobby.

## Implementation tasks and decisions

1. `online_roster.gd` owns validated membership, clan locks, rule revisions and readiness.
   Peer IDs remain stable; fighter slots are reassigned only in the lobby. Online human
   membership is independent of the existing offline FFA mode, which still uses bots.
2. `net.gd` routes input by authenticated RPC sender to each guest's slot, expires stale
   input independently after 250 ms and broadcasts the complete roster and match context.
   ENet admits three clients. WebRTC uses a server/client star: each guest connects only
   to the host, which retains authoritative simulation. No new gameplay server is needed.
3. `web_room.gd` and `/api/rooms` use protocol 3 and a separate Redis key namespace.
   Each guest has an individual peer ID, token hash and acknowledged signaling mailbox.
   Atomic compare-and-set enforces three guest reservations, independent departures,
   and the exact guest list at Start. A fresh join gets a new peer ID even when reusing
   a vacant fighter slot. A 45-second failed negotiation reservation can expire.
4. `online_lobby.gd` replaces the old online branch of clan selection. The name modal,
   four player cards, shared rules, explicit Start, named HUD/results and session exit
   form one flow. Offline clan selection retains its existing controls.

The host keeps admission/signaling polling alive while waiting for more guests. After
Start it sends a room heartbeat every ten seconds, extending the ten-minute room TTL
so the same invitation can be reopened for a rematch. Connected guests stop signaling
once their mailbox is drained. Gameplay remains WebRTC/ENet traffic. Transient room
service failures retry with backoff; Start has a bounded retry deadline and can be
retried safely. Room control commands take priority over the idle heartbeat schedule.
A generation number prevents a stale Start response from starting a later lobby.

Connection admission is reserved in the API, then registered through a protocol/name
handshake with the host. Start freezes local admission and atomically locks API admission;
if a concurrent guest reservation wins, Start reports that someone is still connecting.
JSON peer IDs are normalized to integers before membership lookup in Godot.

## Validation

- Node tests: concurrent fourth-seat admission, private mailboxes, exact-roster Start
  races, host-only actions, retries, departures/replacements, expiry, real Redis CAS,
  protocol mismatch, request bounds and TURN credential isolation.
- GUT: name validation, 2/3/4-player Ready rules, clan conflicts, stale rule revisions,
  stable identities, and the JSON peer-ID regression.
- Scene integration: 2/3/4 authored spawns, all-human fighters, independent input edges,
  last-slot victory, named results, rematch readiness and offline mode isolation.
- Browser tests drive actual input in separate Chrome contexts: required names,
  synchronized rules/readiness, explicit Start, 2/3/4 fighters and input replication,
  fifth-player rejection, disconnection, replacement and host loss. A separate local
  coturn run forces relay candidates and inspects the selected connection route.

Local testing cannot establish WAN latency, production Vercel/Redis/Cloudflare behavior
or cross-browser compatibility. Protocol 3 requires the game export and room API to be
released together; existing protocol-2 invitations are not reused. TURN credentials
retain the existing four-hour lifetime; recreate the room for longer sessions.

## Sources

- [Godot WebRTCMultiplayerPeer server/client modes](https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html)
- [Godot ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)
