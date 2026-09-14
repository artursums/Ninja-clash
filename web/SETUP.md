# Browser hosting and remote play

The browser game supports 2–4 players through invitation links. Friends do not need
to install Godot, download this repository or enter an IP address.

## Services

Create a Vercel project, an Upstash Redis database and a Cloudflare TURN key.
Redis stores room membership and connection messages. Game simulation runs on the
host, with WebRTC carrying gameplay traffic. TURN provides a relay when a direct
connection cannot be established.

1. Create a database in the [Upstash console](https://console.upstash.com/).
   Choose a region near the Vercel Function region. Obtain the REST URL and a token
   with write permission. See the [Upstash REST documentation](https://upstash.com/docs/redis/features/restapi).
2. Create a TURN key in Cloudflare Realtime and retain its key ID and API token.
   Follow [Cloudflare's credential guide](https://developers.cloudflare.com/realtime/turn/generate-credentials/).
   Check the provider's current usage limits and billing before enabling a service.
3. Add the following variables to your Vercel project's environment settings:

| Variable | Value |
|---|---|
| `UPSTASH_REDIS_REST_URL` | Redis REST endpoint |
| `UPSTASH_REDIS_REST_TOKEN` | Redis token with write permission |
| `CLOUDFLARE_TURN_KEY_ID` | TURN key ID |
| `CLOUDFLARE_TURN_API_TOKEN` | Token for that TURN key |

Select Production and Preview where needed. Keep credentials out of source code and
invitation links. Changes apply to new deployments, so redeploy after editing them;
see [Vercel's environment documentation](https://vercel.com/docs/environment-variables/managing-environment-variables).

The room API issues temporary TURN credentials for four hours. Create a new room for
a longer session. Alternatively, configure your own TURN service through `TURN_URLS`
and `TURN_SHARED_SECRET`, as shown in [.env.example](.env.example).

## Deploy from GitHub

Import the repository into Vercel with these settings:

| Setting | Value |
|---|---|
| Application / Framework Preset | Other |
| Root Directory | `./` |
| Production Branch | `main` |
| Build and output settings | Use the root `vercel.json` |

The build script downloads the pinned Godot 4.6.2 engine and export templates,
checks their hashes, imports resources and exports the release game. The root room
API and game are deployed together. Do not select `ninja_clash/` as the Vercel root.
Pushes to the production branch update the public site; other branches produce
Preview deployments. Preview protection may require a Vercel login, so share the
public Production URL for a match with friends.

## Export and deploy with the CLI

From the repository root, with Node.js 22, Godot 4.6.2 and its Web templates installed:

```sh
cd web
npm ci
npm run export
cd ../build/ninja-clash
npx vercel login
npx vercel link
npx vercel deploy
```

Verify the generated Preview URL before running `npx vercel deploy --prod`.
The export command prepares `build/ninja-clash` with `public/`, the room API and its
configuration. A plain Godot export alone does not include the server code.

## First remote match

1. Everyone opens the current Production URL in a separate browser window.
2. The host selects Online, enters a name, creates a room and copies the invitation.
3. Guests open the invitation, enter their names and join.
4. Everyone picks a character and readies up. The host chooses the arena and rules,
   then starts the match.
5. Check movement, jumping, throws, damage and scores on both sides. Keep the host's
   game active. Closing the host returns guests to the online menu.

For a meaningful remote check, use different computers on different networks; a
mobile hotspot is one option. Local browser tests cannot measure internet latency.
Client prediction and host migration are not implemented.

## Troubleshooting

| Symptom | Check |
|---|---|
| `ONLINE SERVICE UNAVAILABLE` | Required variables, deployment environment, Redis access and valid TURN credentials |
| `ROOM EXPIRED OR NOT FOUND` | Open a fresh invitation on the same deployment; waiting rooms expire after ten minutes |
| `HOST IS NO LONGER WAITING` | Keep the host active and create a new room |
| `ROOM IS FULL` | A room holds the host and at most three guests |
| `CONNECTION TIMED OUT` | TURN configuration, network restrictions and a test on another connection |
| Blank canvas or SharedArrayBuffer error | Deploy the provided COOP/COEP headers in `vercel.json` |
| Music starts after a click | Browsers restrict audio before user interaction |
| Guest controls feel delayed | Network quality; the game does not predict client movement |

For a local credential check, copy `.env.example` to the ignored `.env.local` and run
from `web/`:

```sh
node --env-file=.env.local tools/check-config.mjs
```

This checks Redis access and temporary TURN credential issuance without printing
secrets. It does not prove that gameplay traffic can pass through TURN.

## Developer checks

```sh
npm ci
npm test
npm run export -- --debug
npm run test:browser
```

Browser checks use Chrome and the real Godot export. To force relayed connections,
install `coturn` and run `NINJA_TEST_TURN=1 npm run test:browser`. The fixture starts
an isolated loopback TURN service and shuts it down afterward. Redis integration
tests use `redis-server` when installed and otherwise report a skip.

Before publishing, run `npm run export` again to produce a release build with debug
telemetry disabled. Native ENet sessions and browser WebRTC rooms are separate transports.
