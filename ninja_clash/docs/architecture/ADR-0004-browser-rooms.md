# ADR-0004: Browser invitations with WebRTC and short-lived HTTP signaling

Status: implemented locally; production Redis/TURN configuration and deployment pending.
Date: 2026-09-12. Extends ADR-0003 for the Web platform.

## Behavior

The host creates a room, copies an invitation, and waits for one guest. Opening the invitation
selects Join Room; it does not silently claim the guest slot. Once connected, the existing
host-authoritative lobby, simulation and RPC snapshots run through `WebRTCMultiplayerPeer`.
Desktop exports continue using ENet. No native WebRTC extension is required.

## Transport and services

- `web_room.gd` exchanges SDP and trickle ICE through same-origin `/api/rooms` HTTPS POSTs.
  `WebRTCMultiplayerPeer` polls the peer connection and transports gameplay. Host ID is 1,
  guest ID is 2; the existing Godot server/client semantics remain intact.
- `web/api/rooms.js` runs on Vercel Node.js 22. It uses Upstash's Redis REST API. The local
  development server explicitly uses memory; production never silently falls back to memory.
- Rooms are random 48-bit identifiers carried in URL fragments, with independent 256-bit
  session tokens. Only token hashes are stored. Guest admission and mailbox writes use
  compare-and-set Lua so separate function invocations cannot admit two guests.
- Mailboxes have monotonically increasing sender sequences, receiver acknowledgments and
  idempotent retries. A lost HTTP response does not discard or duplicate signaling messages.
  Schemas, body sizes, batch sizes, sequence counts and per-IP rates are bounded.
- Waiting rooms expire after ten minutes. A host must have polled within 30 seconds to admit
  a guest. Negotiation has a 45-second deadline. Once both peers have connected and all ICE
  messages are acknowledged, signaling stops; Redis is not a gameplay dependency.
- The server issues four-hour TURN credentials through Cloudflare's credential endpoint, or
  through HMAC-SHA1 for an explicitly configured coturn server. Production requires TURN.
  Long-term keys stay on the server. The browser tries direct connectivity and can fall back
  to relay. Recreate the room for sessions exceeding the credential lifetime.
- Missing remote input is cleared after 250 ms so a stalled/backgrounded guest cannot leave
  a direction stuck indefinitely. This is not client-side prediction or reconnection.

## Alternatives

We chose short-lived HTTP signaling over a persistent signaling WebSocket: only the initial
handshake needs the service, and this avoids connection lifetime/state affinity requirements
in Vercel Functions. Polling adds some setup latency and Redis requests while waiting.
WebSocket gameplay through a dedicated game server would add ongoing server simulation and
hosting responsibilities. The existing two-player host-authoritative model fits WebRTC.

## Limitations and verification

The host's browser must remain active. Closing it ends the match. A guest reconnects through
a new room; automatic resumption is not implemented. Browser and native transports do not
interoperate. Protocol version 2 is checked on room admission; increment both server and
client protocol constants when changing the RPC/wire contract.

Tests cover atomic admission with real Redis Lua via the REST adapter, signaling retries,
credentials, invalid/expired/closed rooms, and real Godot exports driven in two Chrome
contexts. The TURN browser test forces `iceTransportPolicy: relay` and checks the selected
candidate's type, rather than inferring relay use from the presence of TURN configuration.
Test telemetry is read-only and attached only to debug Web exports.

Local loopback tests do not measure WAN latency, loss, Cloudflare's live service, Vercel
deployment behavior, or compatibility with other browsers. The release must still be tested
after the owner configures the services, including a match between separate networks.

## Sources

- [Godot WebRTCMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html)
- [Godot WebRTCPeerConnection](https://docs.godotengine.org/en/stable/classes/class_webrtcpeerconnection.html)
- [Vercel Node.js functions](https://vercel.com/docs/functions/runtimes/node-js)
- [Upstash REST API](https://upstash.com/docs/redis/features/restapi)
- [Cloudflare temporary TURN credentials](https://developers.cloudflare.com/realtime/turn/generate-credentials/)
