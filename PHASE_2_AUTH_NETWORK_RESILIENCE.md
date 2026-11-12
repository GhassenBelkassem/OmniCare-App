# Phase 2 — Authentication & Network Resilience

Date: 2026-11-09  
Status: **IMPLEMENTATION VERIFIED — PHYSICAL-DEVICE FAULT MATRIX PENDING**  
Findings addressed: **F-02, F-09, F-17**

## Scope and decision

This phase hardens the existing shared `AppHttpClient`, refresh coordinator, authentication
restoration, and medical-document upload path. Phase 2C consumes the already-implemented upload
recovery contract; it does not add a second HTTP client, a global retry policy, a cache, a
state-management framework, a dependency, or another backend contract.

The implementation and repository test gates are complete. Phase 2 remains open because its exit
criteria require Android/iOS runtime evidence under offline startup, network handoff, stalled
uplink, token expiry, large upload, cancellation, backgrounding, and process termination. Those
conditions were not available in this environment and are not represented as completed.

## Backend contracts verified

- Refresh-token rejection uses `AUTH_REFRESH_TOKEN_INVALID`; authenticated session rejection uses
  `AUTH_SESSION_INVALID` or `AUTH_SESSION_EXPIRED`.
- The backend multipart boundary is 20 MB (`spring.servlet.multipart.max-file-size`). The client
  enforces the same limit before creating an upload operation.
- Document creation already uses an `Idempotency-Key`. The same operation key is retained after a
  timeout, cancellation, or refresh-required result so a user retry does not manufacture a second
  logical write.
- `GET /api/v1/documents/uploads/recovery?patientId=<UUID>` accepts the original
  `Idempotency-Key` and returns the actor/subject-authorized `IN_PROGRESS`, `SUCCEEDED`, or `FAILED`
  projection. Missing, expired, and foreign operations fail with the non-enumerating
  `DOCUMENT_UPLOAD_RECOVERY_NOT_FOUND` contract.

## Authentication refresh behavior

`AuthRefreshCoordinator` now returns a typed `AuthRefreshResult` rather than collapsing every
failure to `null`:

| Outcome | Local session | Caller behavior |
|---|---|---|
| Refresh succeeds | Rotated session stored atomically | Retry only when the original request is safe to replay |
| No stored session / locally expired refresh token | Cleared | Unauthenticated |
| HTTP 400/401 with an exact authoritative auth code | Cleared and invalidation callback invoked | Unauthenticated |
| DNS/TLS/connection/send/receive failure | Preserved | Recoverable failure |
| HTTP 5xx or non-authoritative error | Preserved | Recoverable failure |
| Malformed successful refresh payload | Preserved | Incompatible/recoverable failure |
| Logout races an in-flight refresh | Generation-fenced and cleared by logout | Logout remains authoritative |

The existing single-flight future is preserved. Ten concurrent 401 responses are covered and issue
one refresh request. A refresh outage is propagated as
`AUTH_REFRESH_TEMPORARILY_UNAVAILABLE`; a malformed refresh response is propagated as
`AUTH_REFRESH_MALFORMED_RESPONSE`. Neither can be mistaken for invalid credentials by
`AuthRepository.restoreSession`.

`SplashScreen` no longer routes a transient restoration failure to login. It renders a retry state,
keeps the encrypted stored session, and proceeds only after authentication can be verified.

## Request timeout and replay policy

- Both shared Dio instances now have 30-second connect, send, and receive timeouts.
- Safe reads (`GET`, `HEAD`, `OPTIONS`) may be replayed once after a successful single-flight
  refresh.
- A write may be replayed once only when it carries a non-empty `Idempotency-Key` and its body is
  reconstructable.
- `FormData`, stream, and multipart bodies are never replayed by the interceptor, even when an
  idempotency key exists.
- After refreshing credentials for a non-replayable request, the interceptor returns the typed
  `AUTH_REPLAY_REQUIRED` condition. The owning API must rebuild the body and retry using the same
  operation identity.
- A repeated authoritative 401 after a replay invalidates the session; an unrelated or malformed
  401 does not silently destroy credentials.

The policy is O(1) per request and adds no retry loop. It prevents consumed multipart streams from
being resent and prevents non-idempotent JSON commands from being duplicated automatically.

## Medical-document upload

- Android/iOS selection now requests a file path without loading the complete file into Dart heap.
- Web retains bounded bytes because browser file access does not provide a native path; the same
  20 MB boundary applies.
- `DocumentUploadOperation` records exactly one source (path or bytes), the declared size, metadata,
  and one stable idempotency key.
- Every upload attempt rebuilds a fresh `MultipartFile`/`FormData`. Path uploads are streamed by Dio
  and use O(1) application memory relative to file size; transfer work is O(n) in file bytes.
- Upload send timeout is explicitly bounded at two minutes instead of inheriting an unbounded send.
- Dio `CancelToken` and send-progress callbacks are wired from the API to the dialog.
- The dialog blocks dismissal while an upload is active, displays progress, and exposes an explicit
  cancel action. Screen disposal also cancels the request.
- Cancellation and refresh-required outcomes keep the pending operation identity. Retrying the same
  selected file reuses the idempotency key and reconstructs the multipart body.
- Empty, oversized, ambiguous, size-mismatched, unreadable, and unsupported backend file outcomes
  fail with safe typed messages and no medical payload logging.

### Process-death recovery

- Before the first multipart dispatch, `MedicalDocumentUploadController` writes one versioned
  secure receipt containing only schema version, authenticated account scope, operational Patient
  ID, upload idempotency key, and creation time. It never stores bytes, paths, filenames, MIME,
  document metadata, medical content, or credentials.
- The production bootstrap owns one eager account-scoped controller using the shared
  `DocumentsApi`. After authentication and the Patient profile are known, cold start reads the
  receipt and performs the non-mutating recovery GET before any new multipart submission.
- Same-session timeout, cancellation, response loss, and other post-dispatch ambiguity use that
  same recovery-first path. The multipart request is not resent while a receipt remains unresolved.
- `SUCCEEDED` accepts the authoritative document, reconciles the document list, and deletes the
  receipt. `IN_PROGRESS` retains the receipt and continues through authoritative status/list
  reconciliation. `FAILED` and `DOCUMENT_UPLOAD_RECOVERY_NOT_FOUND` delete the terminal receipt
  and require explicit new user intent with a newly generated key.
- Temporary recovery failure retains the receipt for later foreground/cold-start recovery. A local
  receipt reaching the backend-aligned 24-hour horizon expires safely and never causes a blind
  resubmission.
- Logout/account change cancels and generation-fences the live exchange, clears that account's
  receipt, and prevents late callbacks or another account from consuming it.

## Verification

Completed evidence:

- Focused auth/network/document/Phase 1 gate: 153 passed, 7 intentionally skipped, 0 failed.
- Full bounded Flutter suite: 1,688 passed, 7 intentionally skipped, 0 failed in 3 minutes 38
  seconds.
- Full `flutter analyze --no-pub`: 388 findings = 0 errors, 31 warnings, 357 infos. The warning
  count remains the Phase 0 baseline and the total is one informational finding lower than the
  recorded 389 baseline.
- Standalone Phase 1 boundary: 6 passed, 0 failed.
- `git diff --check`: passed.

Coverage includes authoritative invalidation, refresh 5xx, transport failure, malformed response,
ten simultaneous 401s, safe-read replay, idempotent-write replay, non-idempotent JSON non-replay,
multipart non-replay, startup recovery, 20 MB boundaries, path-backed upload, progress,
cancellation, same-key retry, secure receipt schema/content, receipt-before-dispatch ordering,
cold-start recovery without the original file, response-loss recovery without a second POST, all
four recovery outcomes, 24-hour expiry, account/logout isolation, and late-callback fencing.

## Remaining production evidence

The following must be run on signed staging builds before Phase 2 can exit:

1. Android and iOS offline cold start with an encrypted saved session, followed by recovery.
2. Wi-Fi/mobile handoff, DNS failure, TLS failure, packet loss, and backend refresh outage.
3. Expired access token with valid and invalid refresh tokens against staging.
4. Real 20 MB upload, slow/stalled uplink, cancellation at early/mid/late transfer, and safe retry.
5. Android background, force-stop/process kill, and relaunch before dispatch, during transfer,
   after backend commit but before response, while recovery is `IN_PROGRESS`, and after recovery
   becomes terminal.
6. iOS background/suspension, termination, and relaunch at the same upload/recovery boundaries.
7. Backend reconciliation proving one document record for the same operation key and a fresh key
   only after an authoritative terminal result.

Until those results exist, F-02/F-09/F-17 are code- and test-remediated but not physically
certified. The stable Phase 2 transport/idempotency/recovery contracts are sufficient for Phase 3
engineering to begin in parallel, but Phase 3 must not claim these Phase 2 runtime criteria have
passed and Phase 2 cannot exit from source or widget evidence alone.

