# G-2 · Dev WebSocket origins — Flutter Web (localhost, any port) can open `/api/v1/ws`
_Date: 2026-11-11 · Repo: **OmniCare-BackEnd** (working tree on `feature/g1-p2b-single-page`, which also holds uncommitted G-1 work; see §7) · Local/dev only, production unchanged except a stricter startup check_
_Testing rule (CTO): automated tests cover logic only; the CTO tests by hand (§9)._

## 1. Goal card and deliverable status

```
GOAL G-2: Connect the patient Flutter app to the real backend without changing the current UI, with a report at every step.
Deliverables:
  1. A full, detailed roadmap for the patient app, consultation excluded
  2. The patient Flutter app connected to the backend (no UI redesign)
  3. A report for every step (saved in the repo)
  4. Claude Code prompts that enforce design patterns, clean code, bounded complexity/memory, and official docs
Done when: every patient screen reachable from production main.dart shows real data or an honest
"indisponible" state (no fixture, no mock), the release build passes the G-2 gate (§8), and every
step has a report in OmniCare-App/docs/reports/G2/.
```

| # | Deliverable | Status |
|---|---|---|
| 2 | Patient app wired | 🔨 unblocks local testing of realtime (notifications STOMP) from Flutter Web |
| 3 | Report per step | 🔨 + this report |

**Result:**
- **Root cause:** a local configuration override, not the code. The committed `.env.dev.example` pinned `WEBSOCKET_ALLOWED_ORIGINS` to port **4200**, and that env value overrides the dev profile's any-port default. So Angular (:4200) connected while Flutter Web (random port) got **403**. REST worked because `CORS_ALLOWED_ORIGINS` was not pinned in `.env`.
- **Fixed in the committed templates** (`.env.dev.example`, `.env.example`). The dev default now uses the documented `[*]` port syntax.
- **One gap in the production startup check closed:** it accepted `https://[::1]` (IPv6 loopback in brackets).
- **Your own `.env` still has the old pin.** Remove that one line (§9, step 1); I did not edit your `.env`.

## 2. Plan findings (step 1)

### How allowed origins are set today
| | REST CORS | WebSocket `/api/v1/ws` (STOMP + SockJS) |
|---|---|---|
| Code | `ApiCorsConfiguration.java:23` → `CorsConfiguration.setAllowedOriginPatterns(CorsProperties.allowedOrigins())` | `WebSocketConfig.java:38-43` → `registry.addEndpoint("/api/v1/ws").setAllowedOriginPatterns(WebSocketProperties.allowedOrigins()).withSockJS()` |
| Property | `omnicare.cors.allowed-origins` (`CorsProperties`) | `omnicare.websocket.allowed-origins` (`WebSocketProperties`) |
| Default (`application.yaml`) | `${CORS_ALLOWED_ORIGINS:}`: empty, strict | `${WEBSOCKET_ALLOWED_ORIGINS:}` (`:262-263`): empty, so same-origin only |
| Dev profile (`application-dev.yaml`) | `${CORS_ALLOWED_ORIGINS:http://localhost:*,http://127.0.0.1:*}` | `${WEBSOCKET_ALLOWED_ORIGINS:http://localhost:*,http://127.0.0.1:*}` (before) |
| Prod profile | `${CORS_ALLOWED_ORIGINS:}` | `${WEBSOCKET_ALLOWED_ORIGINS:}` |
| Startup check outside dev/local/test | `CorsProductionConfigurationValidator` | `WebSocketProductionConfigurationValidator` (`@Profile("!dev & !local & !test")`): non-empty, HTTPS only, no `*`, no localhost |
| HTTP security | — | `/api/v1/ws/**` is `permitAll` at the HTTP layer (`AuthWebSecurityConfig.java:278`); STOMP CONNECT is authenticated by `WebSocketAuthInterceptor` (untouched) |

The mechanism the task asked for already existed: one property, empty by default, localhost patterns in dev, and a production check. **Why REST and WebSocket behaved differently on your machine:**
- `.env` is imported as Spring properties (`application.yaml:3`, `spring.config.import: optional:file:.env[.properties]`).
- Your `.env` sets `WEBSOCKET_ALLOWED_ORIGINS` to localhost and 127.0.0.1 on **port 4200 only** (I checked the port numbers only, no other values). It does not set `CORS_ALLOWED_ORIGINS`.
- So REST used the dev default (any port), and the WebSocket used the 4200 pin.
- The pin came from the committed template `.env.dev.example:9` (`…localhost:4200,…127.0.0.1:4200`). `.env.example:244` had the same.
- Flutter Web serves on an ephemeral port, so the SockJS origin check answered **403**.

### Official documentation used
- Spring Framework reference (6.2), **WebSockets → WebSocket API → "Allowed Origins"** (`docs.spring.io/spring-framework/reference/web/websocket/server.html#websocket-server-allowed-origins`). The default for WebSocket and SockJS is same-origin only; otherwise a list of origins, each starting with `http://` or `https://`, or `*` for all.
- `CorsConfiguration#setAllowedOriginPatterns` javadoc (since 5.3), the syntax `setAllowedOriginPatterns` uses: "`https://*.domain1.com:[*]` — … on any port, including the default port". Hence `http://localhost:[*]`. A matched pattern echoes the concrete origin, never `*`, so it stays compatible with credentials.
- Version in use: Spring Framework 6.2.19.

## 3. What changed (backend)
| File | Change |
|---|---|
| `.env.dev.example` | The `WEBSOCKET_ALLOWED_ORIGINS=…:4200…` line is replaced by a comment: not set on purpose, so `application-dev.yaml` governs. Set it only for hosted dev, to a concrete HTTPS origin |
| `.env.example` | `WEBSOCKET_ALLOWED_ORIGINS=http://localhost:[*],http://127.0.0.1:[*]` with a "local only" comment |
| `src/main/resources/application-dev.yaml` | Dev default `http://localhost:[*],http://127.0.0.1:[*]` (documented port syntax; `:*` also matched, but not the default port) plus an explanation comment |
| `src/main/java/…/auth/config/WebSocketProductionConfigurationValidator.java` | Loopback detection moved into `isLoopback(host)`: `localhost`, `*.localhost` (RFC 6761), `127.0.0.0/8`, and `::1` / `0:0:0:0:0:0:0:1` **with or without brackets**, case-insensitive, no DNS lookup. Before, `URI.getHost()` returned `"[::1]"`, so the `"::1"` comparison never matched and **`https://[::1]` passed in production**; `127.0.0.2` and `LOCALHOST`-style variants were also not covered by name |
| `src/test/java/…/config/WebSocketOriginHandshakeTest.java` (new, 4 tests) | see §4 |
| `src/test/java/…/auth/config/WebSocketProductionConfigurationValidatorTest.java` | +2 tests: the dev patterns, Flutter-style ports and loopback variants are refused; the check runs in `prod` (and with no profile) but not in `dev` / `local` / `test` |

Not touched: `application.yaml` (it has uncommitted G-1 edits), `application-prod.yaml`, CORS, authentication, `WebSocketAuthInterceptor`, STOMP authorization, session checks, and the `consultation`, `clinicalrecord`, `medicalsharing` and `mrs` packages. No app (Flutter) change.

## 4. Evidence

| Check | Result |
|---|---|
| New and updated WebSocket tests (`WebSocketOriginHandshakeTest`, `WebSocketConfigTest`, `WebSocketProductionConfigurationValidatorTest`) | **10/10 pass** |
| Affected module: every test under `com.omnicare.app.auth.**` and `com.omnicare.app.config.**` | **417 run, 0 failures, 0 errors** |
| Failing check before the fix | The new `[::1]` case failed against the old validator (it did not throw) and passes after the fix |

**How the tests were run.** The backend working tree holds the consultation chat's (G-1) **uncommitted** changes, and with them the test sources don't compile (`PatientChartDtos` changed in `patientchart`, its tests not yet). I left those files alone. Instead I ran everything in a temporary detached `git worktree` at the committed `HEAD` (`cebfd38`) plus only my 6 files, then removed the worktree.
- That worktree has no `.env` (gitignored, holds secrets; not copied), so I passed only `SPRING_PROFILES_ACTIVE=dev`.
- A first run without it gave 45 context-load errors (`Profile '${SPRING_PROFILES_ACTIVE}'…`), all environmental.

**New handshake tests.** These run through the real `WebSocketConfig.registerStompEndpoints`: a real `WebMvcStompEndpointRegistry`, then its handler mapping, then the SockJS handler and its CORS interceptor. The origins are bound from the real `application-dev.yaml` / `application-prod.yaml` files (placeholders resolved without environment variables). Both SockJS entry points are covered: `/api/v1/ws/info` (sockjs-client, Angular) and `/api/v1/ws/{server}/{session}/websocket` (stomp_dart_client in SockJS mode, which is what the Flutter app uses, `authenticated_realtime_transport.dart:93`).
1. **Dev profile:** origins resolve to `http://localhost:[*]`, `http://127.0.0.1:[*]`. `http://localhost:5173`, `http://127.0.0.1:61234` and `http://localhost:4200` → `/info` **200**, and the WebSocket transport is **not 403** (it reaches the upgrade-header check).
2. **Dev profile** still rejects `https://attacker.example` → **403** on both paths.
3. **Root cause reproduced:** with the old `:4200` pin, Angular gets 200 and Flutter Web (`:5173`) gets **403** on both paths.
4. **Prod profile:** the default (empty) and a configured `https://app.omnicare.tn` both reject `http://localhost:5173` → **403** on both paths; `https://app.omnicare.tn` → 200.

**Startup check.**
- Refuses `http://localhost:[*]`, `http://127.0.0.1:[*]`, `http://localhost:5173`, a mixed list, `https://[::1]:8443`, `https://127.0.0.2`, `https://app.localhost` and `https://LOCALHOST`, plus the existing cases (`*`, `https://*.…`, `http://…`, `https://localhost:4200`, a path).
- Accepts concrete HTTPS origins.
- Is active for `prod` and for no profile; inactive for `dev`, `local` and `test`.

## 5. Contract
| Endpoint | Before (your local `.env`) | After, dev profile, no override | Prod |
|---|---|---|---|
| `GET /api/v1/ws/info`, `…/{server}/{session}/websocket` with `Origin: http://localhost:<any>` | 403 unless the port is 4200 | accepted, then STOMP CONNECT auth as before | 403 (only the configured HTTPS origins) |
| Same with a foreign origin | 403 | 403 | 403 |

## 6. Complexity
Configuration only, plus O(1) string checks at startup. No runtime path changed.

## 7. Risks, open questions, things not done
- **R1. Your local `.env` still pins port 4200.** It is gitignored and holds secrets, so I did not edit it. Remove the `WEBSOCKET_ALLOWED_ORIGINS=` line (§9, step 1), or every Flutter Web handshake will keep getting 403.
- **R2. Same trap for REST in `.env.example`.** Its `CORS_ALLOWED_ORIGINS` (line 243) is still pinned to `:4200`. Anyone who copies `.env.example` whole will see REST blocked from Flutter Web too. I left it, because this task is scoped to the WebSocket. Recommend the same `[*]` change.
- **R3. Shared working tree with G-1.** The backend checkout is on G-1's branch with its uncommitted work, and its tests don't compile right now. Commit my 6 files on their own (separate branch recommended, §8) so they don't mix with G-1's changes. This change also goes through the omnicare-code-review rule (§1.4 of the roadmap).
- **R4.** The production check is now slightly stricter (IPv6 / `127.x` / `*.localhost`). Any production configuration that relied on those would now fail at startup, which is intended. Your staging and prod values are not known to me.
- Not done: the full backend suite (it needs the G-1 tree to compile and the local `.env` / Testcontainers); the CORS template (R2).

## 8. Path to deliver G-2
1. **CTO:** fix your local `.env` (§9, step 1), run the manual steps, and review and commit the 6 backend files on their own branch (commands in the chat summary).
2. **Then 1a-4** (`NO_SHOW`, C10) **and 1a-5** (push semantic `type`, F7).
3. Decide R2 (the CORS template), then Phase 1b.

## 9. Manual test steps for the CTO
1. **Fix the local override.** In `OmniCare-BackEnd/.env`, delete the line that starts with `WEBSOCKET_ALLOWED_ORIGINS=` (or set it to `http://localhost:[*],http://127.0.0.1:[*]`). Keep `SPRING_PROFILES_ACTIVE=dev`.
   - One-liner with a backup: `cd OmniCare-BackEnd && cp .env .env.bak && sed -i '' '/^WEBSOCKET_ALLOWED_ORIGINS=/d' .env`
   - Restart the backend.
   - Send back: "done".
2. **Handshake from Chrome.** Run the Flutter app in Chrome (`flutter run -d chrome`, any port). Log in as a patient. Open DevTools → Network → filter `ws`.
   - Expected: a request to `…/api/v1/ws/<n>/<id>/websocket` with status **101 Switching Protocols** (before: 403). The app shows no realtime error.
   - Send back: a screenshot of the Network row (status column).
3. **Angular still works.** Open the Angular app on `http://localhost:4200` and log in.
   - Expected: its SockJS connection still succeeds (`/api/v1/ws/info` 200).
   - Send back: "OK" or a screenshot.
4. **Foreign origin still refused (optional):** `curl -i -H "Origin: https://attacker.example" http://localhost:8080/api/v1/ws/info`
   - Expected: `HTTP/1.1 403`.
   - Then the same with `-H "Origin: http://localhost:5173"`. Expected: `HTTP/1.1 200` with `Access-Control-Allow-Origin: http://localhost:5173`.
   - Send back: both status lines.
5. **Prod check (optional, local):** start the backend with `SPRING_PROFILES_ACTIVE=prod` and `WEBSOCKET_ALLOWED_ORIGINS=http://localhost:[*]`.
   - Expected: startup fails with « WEBSOCKET_ALLOWED_ORIGINS must contain only approved HTTPS origins… ».
   - Send back: the error line.
