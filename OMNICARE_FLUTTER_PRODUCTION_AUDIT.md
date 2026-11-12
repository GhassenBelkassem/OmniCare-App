# OmniCare Flutter Production-Readiness Audit

Audit date: 2026-11-08  
Repository: `OmniCare-App`  
Inspected branch/commit: `deployrailway` / `ff88c76`  
Scope: Flutter mobile client and its Android/iOS integration; backend behavior was considered only where the client contract depends on it.  
Method: source/configuration inspection plus non-mutating diagnostics. No application source, dependency constraint, UI, navigation, or backend file was changed.

## Official baseline used

The assessment uses current primary guidance as a baseline, while treating that guidance as adaptable rather than as a required architecture label:

- Flutter's [architecture guide](https://docs.flutter.dev/app-architecture/guide) emphasizes explicit UI/data responsibilities and repositories as sources of truth.
- Flutter's [testing overview](https://docs.flutter.dev/testing/overview) recommends unit/widget coverage plus enough integration tests for important use cases.
- Flutter's [performance profiling guidance](https://docs.flutter.dev/perf/ui-performance) says performance conclusions should be made in profile mode on physical devices, especially the slowest supported class.
- Flutter's [accessibility testing guidance](https://docs.flutter.dev/ui/accessibility/accessibility-testing) requires automated checks plus Android/iOS assistive-technology testing.
- Firebase's [Flutter message handling guidance](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages) distinguishes foreground, background, and terminated behavior and requires a registered background handler for background data-message work.
- Android documents that a stopped activity's process can be killed and all in-process objects lost in the [activity lifecycle guidance](https://developer.android.com/guide/components/activities/activity-lifecycle.html), that Android 13+ notifications require declaration and runtime handling of `POST_NOTIFICATIONS` in the [notification permission guidance](https://developer.android.com/develop/ui/compose/notifications/notification-permission), and that release artifacts require a protected upload/release key in the [app-signing guidance](https://developer.android.com/studio/publish/app-signing).
- Apple documents APNs and notification delivery behavior in [User Notifications](https://developer.apple.com/documentation/usernotifications/).

## 1. Executive verdict

### NOT READY

The checked-in application is not safe to release as a production healthcare mobile application.

The decisive reason is not Provider, ChangeNotifier, folder naming, or visual design. It is a reachable patient urgent-home-care journey that displays synthetic doctors and returns a fabricated consultation success without any backend request. A patient can be told that an urgent request is confirmed even though no clinician or server received it. That is a confirmed medical-safety blocker.

Four further critical release failures compound that blocker:

1. Android `release` is explicitly signed with the debug signing configuration.
2. The repository has no Firebase mobile project files, Android Google Services wiring, iOS push entitlement, or evidenced external injection pipeline; Firebase initialization catches and suppresses the failure, leaving critical push unavailable without an operational signal.
3. Any refresh exception, including a temporary DNS/TLS/timeout/5xx failure, clears the secure session. This is especially damaging on unstable mobile networks and at cold start.
4. The clinic-request controller persists an idempotent in-flight operation for process-death recovery, but production never calls its restore method and both entry screens immediately clear the record.

The newer clinic, scheduled-care, urgent-cabinet, authentication, realtime, and medical-sharing areas contain substantial reliability work worth preserving: shared networking, single-flight refresh, cancellation/generation guards, idempotency keys, account-scoped recovery, and REST reconciliation after realtime events. Those strengths mean this is a hardening and correctness program, not evidence that the whole codebase needs replacement. They do not, however, compensate for a reachable synthetic urgent-care path, missing release controls, and a failing/hanging test gate.

## 2. Current architecture

### Repository/build baseline

| Item | Observed state |
|---|---|
| Flutter | No repository pin/FVM file found. Local diagnostic: Flutter 3.41.2 stable. Docker web image: Flutter 3.41.4. |
| Dart | `sdk: ^3.11.0`; local Dart 3.11.0. |
| Version | `1.0.0+1`. |
| Android | `minSdk 24`; Flutter 3.41.2 resolves `compileSdk 36` and `targetSdk 36`; Java/Kotlin target 17. |
| iOS | Deployment target 14.0. |
| IDs | Android `com.omnilinks.omnicare_mobile`; iOS `com.omnilinks.omnicareMobile`. |
| Environments/flavors | No product flavors or Xcode schemes for development/staging/production. API URL is a compile-time `OMNICARE_API_BASE_URL` Dart define; release fails closed if it is absent. |
| Entrypoints | `main.dart` plus `main_demo.dart`, `main_maps_smoke.dart`, and three doctor/urgent preview or synthetic entrypoints. No `main_dev`, `main_staging`, or `main_prod`. |
| JSON/generated code | Models are predominantly handwritten. No `build_runner`/JSON generator is configured. |
| Assets | Broad image/font/animation tree plus tracked `.env` bundled as an asset. |
| Localization | Handwritten map for English/French/Arabic; no ARB/gen-l10n configuration. |
| Scale | 454 Dart files under `lib`, 369 under `lib/features`, approximately 156,208 Dart LOC. |
| Tests | 119 Flutter test files; no `integration_test/`; one golden-test file with five golden expectations; placeholder iOS XCTest only. |
| CI/release | No GitHub Actions, GitLab, Codemagic, or Fastlane configuration. Docker builds Flutter web only. |

### What actually exists

The application is a mixed-generation, feature-oriented Flutter app. Modern features generally follow UI -> ChangeNotifier/controller -> repository -> API -> shared Dio. Older compatibility features sometimes call API classes directly from widgets, and several legacy API/repository classes still return mocks.

```text
main.dart
  -> AppLockService + dotenv (before runApp)
  -> SecureTokenStore
  -> one AppHttpClient + one AuthRefreshCoordinator
  -> AuthRepository -> AuthController
  -> one authenticated SockJS/STOMP transport
  -> scheduled-care + notification realtime coordinators
  -> notification push coordinator
  -> MultiProvider application scope
       -> patient/clinic/request/directory/scheduled-care controllers
       -> MaterialApp + global navigation keys
       -> SplashScreen
            -> restore secure session / refresh / GET auth state
            -> patient home | doctor shell | clinic shell | login

Modern feature request
  Widget -> controller -> repository -> API -> shared Dio -> backend
         <- typed failure/domain model <- parsed response <-

Legacy urgent-home request (reachable)
  patient home -> emergency steps -> demo doctor timer source
  -> ReviewConfirmScreen -> ConsultationsApi mock -> fabricated success UI
```

There is one root `MaterialApp`, a global `NavigatorState`/`ScaffoldMessengerState`, named routes with an `onGenerateRoute`, and a nested patient-content navigator in `NewHomeScreen`. Doctor and clinic workspaces have their own route-scoped controllers. Bottom sheets and `MaterialPageRoute` are used extensively for detail and action flows.

The dependency graph is not uniformly layered, but the most important current defect is not lack of a named pattern. It is coexistence of authoritative and synthetic implementations behind production-reachable routes.

## 3. Application bootstrap and lifecycle

### Startup trace

1. `main()` calls `startOmniCare()` (`lib/main.dart:110-114`).
2. Flutter binding is initialized.
3. `dotenv.load('.env')` and `AppLockService.initialize()` are awaited together before `runApp` (`main.dart:115-124`). This is bounded local I/O, but it delays the first Flutter frame; startup cost must be measured on low-end devices.
4. A single secure token store, HTTP client, auth repository/controller, realtime transport, realtime coordinators, notification center, and push coordinator are constructed (`main.dart:129-162`).
5. `runApp` mounts providers and `MaterialApp` (`main.dart:164-175`, `232-360`).
6. `AuthController.initialize()` is deliberately started after `runApp`, so the Flutter splash can render while token refresh/profile reads occur (`main.dart:177-180`).
7. Local notification initialization is deferred until after the first frame (`main.dart:182-193`).
8. `SplashScreen` observes `AuthController`, then delegates authenticated routing or replaces with `/login` (`lib/features/auth/splash_screen.dart:23-40`).
9. `AuthController.nextRoute` maps patient/onboarding/password-change/doctor/clinic role decisions (`lib/features/auth/application/auth_controller.dart:78-87`).

### Lifecycle behavior

`_AuthStateListener` is the root lifecycle observer (`main.dart:588-662`). On resume it triggers urgent-cabinet recovery plus scheduled-care and notification foreground resync. On inactive/paused/hidden/detached it tells the urgent-cabinet patient controller the app backgrounded. It does not claim a WebSocket will survive background execution; correctness-oriented coordinators perform REST resync on foreground and reconnect.

Session/account transitions stop realtime/push, clear notification and patient controller state, clear clinic context, and clear the in-flight request store (`main.dart:735-790` and following). This is a good account-isolation boundary.

Important lifecycle gaps:

- Generic route restoration is absent. The nested navigator and most multi-step form data are memory-only.
- The clinic-request recovery implementation exists but is not wired into startup or route entry (F-05).
- The reachable legacy urgent-home flow is entirely memory/timer based and synthetic; process recovery cannot make it correct (F-01).
- With a valid but expired access token, transient refresh failure deletes the persisted session (F-02).
- With an unexpired access token but a transient profile read failure, auth initialization becomes `failure`; the splash treats it as not authenticated and routes to login, even though credentials may remain stored (`auth_controller.dart:101-115`, `splash_screen.dart:23-40`).

## 4. State-management map

Provider/ChangeNotifier is the dominant application-state mechanism. It is complemented by 161 `StatefulWidget` declarations, nine `StreamController` declarations, timers, route arguments, and singleton services. No evidence shows that Provider itself is the production problem.

| State owner | Scope | Dependencies | Responsibility | Persistence/authority | Primary risk |
|---|---|---|---|---|---|
| `AuthController` | App | `AuthRepository`, Google sign-in contract | Auth state, role route decision, flow errors | Secure session + backend `/auth/me` authoritative | Transient refresh failure is converted to logout; splash failure path routes to login. |
| `UserProvider` | Patient session | Account/files repositories | Profile, preferences, avatar | Backend authoritative; memory projection | Root consumer also selects locale, so profile/locale changes rebuild `MaterialApp`. Acceptable but broad. |
| `FamilyProvider` | Patient session | Family repository | Family members and mutations | Backend authoritative | Async member switching requires controller cancellation; newer request flows use opaque IDs and backend ownership checks. |
| `AppLockService` | App/device | Secure storage, local auth | PIN/biometric gate, failure throttling | Versionless secure keys; local authority | Real-device upgrade/biometric validation absent. |
| `ClinicContextController` | Session | Clinic repository/store | Selected clinic and revalidation | Secure hint; backend revalidated | Correctly cleared on logout. |
| `ClinicOperationalController` | Session | Clinic repository | Clinic operational/tasks state | Backend authoritative | Large 1,315-line controller increases change/test surface. |
| `RequestSubmissionController` | Patient session | request repository, in-flight store | Draft intent, idempotent submission/retry | Backend result; secure in-flight operation | Restore method never called; entry clears record. |
| `PatientRequestsController` | Patient session | request repository | Request history/detail | Backend authoritative | Status widget tests currently fail. |
| Patient clinic/doctor directory controllers | App session | typed repositories | Search, filter, pagination/detail | Backend authoritative | Generation/cancellation handling is generally strong. |
| `PatientBookingController` / `PatientScheduledCareController` | Patient session | scheduled-care repository | Booking mutation, request/appointment state and list | Backend authoritative; realtime invalidates/refetches | Good source-of-truth design; process re-entry uses identifiers/server reads. |
| `ReservationProvider` | App | default mock repository | Legacy time-slot request | In-memory synthetic | Registered at root; a legacy registered route can display fabricated submission success if reached. |
| `NotificationCenterController` | Session | notification repository | Durable inbox/badge | REST authoritative; realtime invalidates | Push setup can silently be unavailable. |
| `UrgentCabinetPatientLifecycleController` | Patient session | targeted request repository/coordinator | Active cabinet request recovery | Backend authoritative + account-scoped recovery receipt | Strong recovery design; preserve. |
| Doctor auth-shell controllers | Doctor route/session | shared client repositories | Workspace, scheduled care, home presence/offers/commitment, cabinet, active consultation, record | Backend authoritative | Many coordinated controllers; lifecycle and disposal are explicit but need end-to-end device tests. |
| `NotificationService` | Process singleton | local notifications/global nav | Local alerts and open intents | In-memory pending intent | Contains global UI navigation and some PII-bearing debug logs. |
| Screen-local state | Route | widgets/plugins | Forms, scanner, tabs, animations | Memory only | Correct for transient UI; unsafe where a server write outcome is unknown. |

Several legacy classes (`ConsultationsApi`, `DoctorsApi`, `MedicalActsApi`, `ReservationRepository` mock mode) represent synthetic state. Most modern routes avoid them. The urgent-home path does not.

## 5. Networking architecture

### Standard client

`AppHttpClient` owns one authenticated Dio and one refresh Dio, both based at `<OMNICARE_API_BASE_URL>/api/v1` (`lib/core/network/app_http_client.dart:8-66`). It sets 30-second connect and receive timeouts, JSON headers, and the auth interceptor. There is no send timeout. No production `LogInterceptor`, certificate bypass, or `badCertificateCallback` was found.

`main.dart` injects the shared client into modern repositories. Direct `Dio()` construction was found only in `main_demo.dart` and inside `AppHttpClient`. Four legacy APIs can create their own `AppHttpClient` when no client is injected (`AccountApi`, `FamilyApi`, `FilesApi`, `DocumentsApi`); main injects them, but direct legacy widget construction can bypass session-invalidated handling.

### 401 concurrency and replay

The ten-simultaneous-401 case is handled as follows:

- `AuthRefreshCoordinator._refreshInFlight` provides a single-flight refresh (`auth_refresh_coordinator.dart:22-37`). Ten callers share one future rather than issuing ten refreshes.
- A successful refresh updates secure storage, and each original request is replayed once with an `omnicare_auth_retry` marker (`auth_interceptor.dart:35-80`).
- A second 401 invalidates the session; loops are prevented.

This concurrency design is good and should be preserved. The critical defect is classification: `_performRefresh` catches every exception and calls `invalidateSession()` (`auth_refresh_coordinator.dart:70-123`). Network loss is treated the same as an invalid refresh credential.

### Retry/idempotency/cancellation

There is no global retry interceptor, which avoids blindly duplicating writes. Modern critical flows deliberately use operation/idempotency keys and `CancelToken`s:

- Clinic request operation ID is persisted before POST and reused for retry.
- Scheduled-care writes carry idempotency keys.
- Urgent-cabinet submission uses account/attempt identity, an idempotency receipt, and authoritative reconciliation.
- Search and detail controllers commonly use generation checks/cancellation to reject stale responses.

The auth interceptor replays every eligible request once after refresh, including write requests. For ordinary JSON writes protected by server idempotency this is reasonable; streaming `FormData`/upload bodies are not generically replay-safe. The current client also lacks `sendTimeout`, upload progress cancellation as a uniform contract, and a standard download layer.

### Error/DTO handling

Modern domains define typed failures (`RequestFailure`, `ScheduledCareFailure`, clinic/doctor-directory failures) and distinguish authorization, conflict, validation, timeout, and server conditions. Legacy widgets often use broad `catch (e)` and sometimes render `e.toString()`. DTOs are handwritten. Many parsers defensively validate maps/enums, but there are still direct casts and strict parsers where one malformed item can fail a list. The full test suite caught one such contract mismatch in `DocumentStatusEvent.fromSse`.

## 6. Cache/local-storage architecture

No application SQLite/Drift/Hive/Isar database was found. `shared_preferences` is a direct dependency but no application use was found. Persistence is deliberately narrow and primarily uses `flutter_secure_storage`; image caching is implicit through `cached_network_image`.

| Data | Storage | Why | TTL/version | Invalidation | Sensitive | Assessment |
|---|---|---|---|---|---|---|
| Access/refresh tokens, expiries, user/role/session IDs | Secure storage, one JSON session record | Session restoration | Schema v1; token expiry | Logout, invalidation, malformed/expired session | Yes | Appropriate medium; refresh error policy is unsafe. |
| Legacy auth keys | Secure storage | Migration compatibility | Migrated into session record | Deleted after migration | Yes | Explicit migration is good. |
| Installation ID | Secure storage | Stable device identity | No TTL | Not cleared on normal logout | Pseudonymous | Reasonable; upgrade/device-reset behavior needs device validation. |
| App-lock owner/method/PIN salt+hash/failure state | Secure storage | Local privacy gate | Key set; no record schema | Disable/owner changes | Yes | PBKDF2 and throttling are deliberate; upgrade tests absent. |
| Clinic-selection hint | Secure storage, schema record | Resume selected clinic | Schema version; no TTL | Backend revalidation and logout clear | Personal | Appropriate; server remains authority. |
| Clinic request operation + clinic/subject/situation/pickup GPS | Secure storage, schema v2 | Idempotent process-death retry | No TTL | Success, terminal failure, new-entry, logout | Yes, includes location | Storage is appropriate, but comment understates stored pickup data and production never restores it. |
| Urgent-cabinet recovery receipt | Secure storage | Reconcile unknown write outcome | Account-scoped/versioned checks | Terminal/session invalidation | Personal | Strong, deliberate recovery design. |
| Network images (clinic/doctor/profile/family) | `flutter_cache_manager` through `cached_network_image` | Display cache | Package-managed; no app TTL policy | No explicit logout/account clear found | Profile/family images can be personal | Requires privacy/product decision and shared-device validation. |
| Compressed picked images | OS temporary directory | Upload staging | Filename timestamp; no app cleanup | OS only | Potentially personal/medical | Cleanup is not explicit. |

Cache behavior is mostly accidental rather than an application-wide offline strategy. Critical medical records are not intentionally cached in a local database. Most screens require REST reads; cached images can remain while data reads fail. There is no user-visible cache age/freshness model.

Upgrade safety is mixed. The secure session has a schema version and migrates/deletes legacy token keys; clinic and urgent-recovery records also validate version/account identity before use. App-lock keys and the installation ID have no enclosing record-version migration, and there is no checked-in upgrade test that installs a new binary over existing Keychain/Keystore/cache state. Notification-token rotation is handled at runtime, but uninstall/restore, OS credential changes, biometric enrollment changes, and iOS Keychain persistence are **NOT PROVABLE FROM STATIC INSPECTION — runtime validation required**.

## 7. Realtime architecture

One `AuthenticatedRealtimeTransport` owns an authenticated SockJS/STOMP connection for the app session (`lib/core/realtime/authenticated_realtime_transport.dart`). The bearer token is placed in STOMP CONNECT headers rather than the URL. It subscribes to:

- `/user/queue/scheduled-care`
- `/user/queue/notifications`

Ownership is user ID + normalized role. Generation checks, explicit unsubscription, socket teardown, credential fingerprints, and auth-rejection fencing prevent stale sockets and duplicate subscriptions. A transport drop schedules a reconnect after a fixed five seconds (`authenticated_realtime_transport.dart:313-327`). There is no exponential backoff, jitter, cap, or connectivity-aware pause, so a prolonged outage can cause endless fixed-rate attempts.

Most importantly, scheduled-care and notification realtime events are treated as invalidation hints. Connection epochs, foreground resume, and manual refresh trigger authoritative REST fetches. Critical flows therefore have the correct conceptual recovery sequence:

```text
socket event/drop/reconnect
  -> coalesced invalidation
  -> REST read by identifier/list scope
  -> authoritative controller state
```

The root lifecycle observer does not explicitly deactivate the socket in background. Mobile OS suspension will still apply; the app relies on reconnect/resync when foregrounded. That is acceptable for correctness but needs battery/OEM validation and reconnect telemetry.

## 8. Notification architecture

### Implemented Flutter path

`NotificationPushCoordinator` initializes Firebase, requests permission, registers the device, posts the token to `/notifications/token`, listens to foreground messages, notification opens, initial messages, and token registration, and best-effort unregisters on logout (`lib/features/notifications/push/notification_push_coordinator.dart`). `NotificationService` shows local notifications and retains a pending urgent-cabinet open intent if auth/workspace bootstrap is not ready.

A critical urgent-cabinet tap is validated as a UUID-shaped request ID, claimed once, then resolved through `UrgentCabinetPatientLifecycleController.recoverFromNotification()` before navigation (`main.dart:664-687`). The notification payload is not treated as clinical truth. This is a good design.

### Release gap

The repository has none of the following tracked artifacts/configuration:

- `android/app/google-services.json`
- Google Services Gradle plugin wiring
- `ios/Runner/GoogleService-Info.plist`
- an iOS `.entitlements` file with `aps-environment`
- `firebase_options.dart`
- a mobile CI step evidenced to inject those files/capabilities

`Firebase.initializeApp()` is inside a catch-all whose catch silently sets `_messaging = null` (`notification_push_coordinator.dart:30-57`). The comment calls missing project files/entitlements an external setup state, but no external setup pipeline exists in this repository. The checked-in source can build an app that simply has no push and no production alert.

No `FirebaseMessaging.onBackgroundMessage` handler was found. Notification payloads may be displayed by the OS once the native project is correctly configured, but data-only background processing/reconciliation is absent. Android's app manifest also does not itself declare `POST_NOTIFICATIONS`; a release merged-manifest check is required because a plugin could contribute it. iOS requests notification permission immediately after the first Flutter frame, before an evidenced in-context explanation.

## 9. Platform integration

### Android

Observed:

- API 24 minimum, API 36 compile/target under the inspected Flutter SDK.
- Main activity is exported solely as the launcher, `singleTop`, with predictive-back opt-in.
- Fine/coarse location, Internet, and biometric permissions are declared.
- Debug manifest enables cleartext; main/release manifest does not.
- No deep-link/app-link intent filter.
- No explicit camera or Android 13 notification permission in the app manifest. Plugin-manifest merge must be inspected from a completed release build before making a final permission claim.
- No foreground/background service owned by the app.
- No network security config or certificate override.
- No explicit `allowBackup` policy; the effective merged value and secure-storage backup behavior require release-manifest/device verification.
- No `minifyEnabled`/resource shrinking or project ProGuard policy was found.
- Release uses `signingConfigs.getByName("debug")` with a TODO (`android/app/build.gradle.kts:55-60`). This is a confirmed distribution blocker.

The app correctly assumes no permanent background WebSocket execution. Process death remains a product-level problem for route/form state and the unwired clinic-request recovery path.

### iOS

Observed:

- iOS 14.0 target; automatic signing; bundle ID `com.omnilinks.omnicareMobile`.
- Usage strings for when-in-use location, camera, photo library, Face ID, and notifications.
- No ATS exception.
- No associated domains, URL scheme, push entitlement, or background mode in checked-in configuration.
- Geolocator is compiled with `BYPASS_PERMISSION_LOCATION_ALWAYS=1`, consistent with foreground-only location.
- AppDelegate configures the Firebase Messaging notification-center delegate and Google Maps, but no Firebase plist/entitlement is present.
- No native remote-notification background hook beyond plugin delegation.

No release iOS build, code-signing validation, APNs environment, provisioning profile, or physical-device test was possible from this repository state.

### Location, camera/QR, and files

- Location use is foreground-only. Repository-wide search found one-shot `Geolocator.getCurrentPosition()` calls, not an owned `getPositionStream()`. Modern emergency pickup, urgent-cabinet search, and doctor HOME presence paths check service/permission state and distinguish denial/permanent denial; doctor HOME explicitly stops its publication timer in background and requires a deliberate foreground restart (`doctor_home_presence_controller.dart:167-251,477-484`). Accuracy/mock metadata is sent for server assessment. Pickup coordinates are persisted only in the secure in-flight clinic-request record, but that record has no TTL and recovery is unwired (F-05).
- `QRScannerScreen` renders explicit permission/unsupported/initialization failures. Repeated plugin callbacks call `DoctorMedicalAccessController.consume()`, whose `submitting`/`active` state gate prevents double submit; retry reuses the same idempotency key (`qr_scanner_screen.dart:62-83,137-169`; `doctor_medical_access_controller.dart:34-84`). The widget disposes its owned business controller, while camera ownership remains inside `MobileScanner`. Background/foreground camera recovery and native permission behavior remain device-test unknowns.
- Medical-document selection restricts extensions to PDF/JPEG/PNG but reads the complete file into memory with `withData: true`, does not enforce the UI-reported 20 MB limit client-side, and uploads `MultipartFile.fromBytes` without a `CancelToken` or progress contract (`medical_documents_screen.dart:181-195,263-303`; `documents_api.dart:240-300`). Avatar upload does validate non-empty content, an 8 MB limit, and JPEG/PNG magic bytes. Image compression writes timestamped temporary files without app cleanup. The medical-document path is F-17.

## 10. Performance risks

### Confirmed static problems

1. `EditMedicalDataScreen` creates two `TextEditingController`s per document directly inside `build` (`lib/features/home/edit_medical_data_screen.dart:727-755`, `843-848`). Rebuilds replace controllers, reset selection to the end, create avoidable allocations, and leave disposal to garbage collection rather than widget ownership.
2. Several production files are extremely large: `new_home_screen.dart` 3,665 lines, legacy `doctor_dashboard_screen.dart` 3,320, `patient_profile_screen.dart` 2,376, `patient_home_feed.dart` 2,272, and request/clinic/urgent screens above 1,500 lines. Size alone does not prove jank, but broad `setState`/Provider rebuild regions in these files are a confirmed maintainability and rebuild-isolation problem.
3. Root `Consumer2<UserOnboardingProvider, UserProvider>` rebuilds `MaterialApp` to update locale. This is functionally valid but broad and should be profiled when profile changes or family/account state refreshes.
4. There are 47 timer constructions/periodic timers. Critical modern controllers generally cancel them, but fixed polling/reconnect work needs battery/network measurement over long sessions.

### Requires runtime profiling

The following are risks, not claims of measured slowness:

- Cold start cost of secure storage, dotenv asset parse, font initialization, and the first auth/profile network sequence.
- Frame cost in the 3,665-line patient shell, large profile/clinic detail screens, maps, and nested scroll layouts.
- Full-resolution network/image decoding where thumbnails do not supply cache dimensions.
- Memory behavior for maps, scanner, file picker, 8 MB uploads, network-image cache, and long doctor/patient sessions.
- CPU/battery under five-second realtime reconnects, scheduled-care polling, foreground location publishing, and poor networks.
- App size and native symbol/asset contribution. The attempted AAB did not finish, so no size artifact exists.

No startup benchmark, profile-mode integration test, frame-timing harness, memory benchmark, network benchmark, or app-size budget is checked in.

## 11. Memory/resource risks

Systematic searches covered `TextEditingController`, animation/scroll/page/tab controllers, focus nodes, timers, stream subscriptions, realtime listeners, location usage, and scanner ownership.

Positive findings:

- The authenticated realtime transport unsubscribes and tears down sockets with generation fencing.
- Root auth listener removes its lifecycle observer and cancels notification subscriptions.
- Modern directory/detail controllers cancel requests and dispose listeners.
- `QRScannerScreen` disposes its manual controller and any scanner controller it owns.
- Doctor/urgent timers and most widget controllers have explicit `dispose()` paths.

Confirmed risks:

- Controllers created in `EditMedicalDataScreen.build` have no stable owner/dispose path (F-14).
- `FilePickerService` writes timestamped compressed images to the temporary directory but never deletes them (`lib/core/services/file_picker_service.dart:24-42`). The OS may eventually reclaim them, but the app does not bound retention.
- `NotificationPushCoordinator._seenMessageIds` is session-bounded only; it is cleared at stop, but can grow for a very long uninterrupted session.
- `NotificationService` is a process singleton with a broadcast stream that is never closed. Its ownership is app-lifetime, so this is not by itself a leak; it should remain explicit.

No other missing disposal was proven strongly enough to label a leak. Physical-device memory profiling is still required.

## 12. Security/privacy risks

1. Android release signing uses the debug certificate (F-03).
2. `.env` is tracked and bundled as an application asset (`pubspec.yaml:98-112`). It contains API/configuration keys including a Cloudinary cloud name and upload preset. Values are deliberately redacted here. Client-bundled values must be treated as public; abuse controls must live in Cloudinary/backend policy. `API_BASE_URL` in `.env` is not used by `AppEnvironment`, which uses a Dart define, creating configuration ambiguity.
3. Profile/family/clinic/doctor images use disk-backed `cached_network_image`, but no logout/account-switch cache purge or healthcare privacy policy was found.
4. Compressed selected images remain in temporary storage until OS cleanup.
5. No screenshot/task-switcher protection was found for medical screens. Whether screenshots must be blocked is a product/regulatory decision, not automatically a defect; the current behavior needs an explicit privacy decision.
6. `NotificationService` debug logs include doctor names for on-way/arrival alerts (`lib/services/notification_service.dart:254`, `295`). The logging utilities have no centralized release gate/redaction policy. No Dio body/token logger was found, which is positive.
7. Named-route handlers perform direct casts such as `settings.arguments as Map<String,dynamic>` (`main.dart:468-557`, patient nested navigator `new_home_screen.dart:356-418`). A malformed/stale deep-link or internal route can crash before authorization/reconstruction. Native deep links are not currently configured, limiting present exposure but not correctness risk.
8. Tokens use secure storage, bearer tokens are not placed in WebSocket URLs, no TLS validation override was found, release HTTP is not enabled, and critical notification request IDs are re-fetched/authorized. These are strengths.

No actual secret value is reproduced in this report.

## 13. Testing status

### Inventory

- 119 Dart test files.
- Approximately 886 `test(...)` calls and 642 `testWidgets(...)` calls by static count.
- 77 files contain widget tests.
- Five `matchesGoldenFile` expectations in `patient_home_feed_test.dart`.
- No `integration_test/` directory or device-driven end-to-end suite.
- One default placeholder `RunnerTests.swift`; no meaningful native Android/iOS tests.
- Extensive hand-built fakes/fixtures around clinic, request, scheduled care, doctor, urgent cabinet, realtime, maps, and notifications.
- Coverage was not measured; no coverage percentage is claimed.

### Critical-journey matrix

| Journey | Status | Evidence/gap |
|---|---|---|
| Signup/login/session restore | PARTIALLY TESTED | `auth_phase1_test`, auth fakes, demo auth tests; no real secure-storage/Google/biometric/device/network-transition E2E. |
| Profile/preferences/avatar | PARTIALLY TESTED | Patient profile/widget tests; no native picker/upload interruption or disk-cache privacy test. |
| Family member mutation/switch | PARTIALLY TESTED | Request subject and profile tests; no end-to-end account/family switch with in-flight requests. |
| Ma Santé/medical data | PARTIALLY TESTED | Passport/profile screens and controllers; legacy editor controller issue; no real medical-document upload E2E. |
| Appointment create/cancel | TESTED AT UNIT/WIDGET LEVEL | Scheduled-care foundation/lifecycle/patient/doctor tests are broad; no full backend/device integration test. |
| Clinic care request | PARTIALLY TESTED | Strong request-core/idempotency tests; production process-death restore wiring is absent. |
| Urgent HOME request | INVALID PRODUCTION IMPLEMENTATION | UI tests exist, but production route uses demo matching and mock consultation success. Tests cannot establish real correctness. |
| Urgent CABINET request/recovery | TESTED AT UNIT/WIDGET LEVEL | Large discovery/submission/lifecycle/recovery suite and authoritative repository path; no physical-device/network/OEM E2E. |
| Realtime reconnect/reconciliation | TESTED AT UNIT LEVEL | `scheduled_care_realtime_test` and foreground refresh tests; no real broker/network handoff test. |
| Push notification handling | PARTIALLY TESTED | Notification center/navigation logic tested; no configured FCM/APNs device test, background delivery, token rotation, or terminated launch. |
| QR/medical access | PARTIALLY TESTED | QR widget/controller tests; no real camera permission/lifecycle/expired-code/network device E2E. |
| Doctor scheduled-care/cabinet workflow | TESTED AT UNIT/WIDGET LEVEL | Many doctor shell/agenda/appointment/cabinet tests; no release device/backend E2E. |
| Nurse workflow | UNTESTED/NOT EVIDENCED | No production nurse feature/test journey identified. |
| Kiné workflow | UNTESTED/NOT EVIDENCED | Legacy provider type explicitly reports unsupported; no production journey test. |
| Medical Passport access/sharing | PARTIALLY TESTED | Passport, medical sharing, doctor medical record tests; native QR/push/process interruption untested. |
| Logout/session expiry | PARTIALLY TESTED | Auth/session/controller tests exist; transient refresh failure policy is wrong and no poor-network device test exists. |
| Accessibility/localization | UNTESTED AS SYSTEM | A keyboard-navigation test exists, but no semantics guideline suite, text-scale matrix, TalkBack, VoiceOver, or complete locale screenshots. |

### Diagnostic outcome

`flutter test --reporter compact` did not pass. At 6 minutes 7 seconds it reported `+1580 ~7 -13` and remained stuck in `review_screen_test.dart`; it was interrupted. Known reproducible failures include:

- `test/core/api/documents_api_test.dart`: 1 failure. A minimal terminal event with an opaque UUID throws `FormatException: Document event ID binding mismatch` at `lib/core/api/documents_api.dart:155`.
- `test/patient_request_status_matrix_test.dart`: 4 of 11 cases fail. `REQUEST_RECEIVED` and `UNDER_REVIEW` copy is absent; `COMPLETED` and `CANCELLED` each render the expected label twice while tests require exactly one.
- The full run had 13 failures before interruption, so the two rerun files do not account for every failure.

The repository therefore does not currently have a passing or terminating test gate.

## 14. Production observability status

Production observability is effectively absent.

No `FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded`, Crashlytics, Sentry, structured telemetry, performance telemetry, API failure metrics, WebSocket reconnect metrics, or release breadcrumb context was found. Logging is ad hoc `print`/`debugPrint`/custom console output, with no centralized PII/medical-data redaction contract and no systematic app version/OS/device/session correlation.

After a production incident, the team could inspect backend logs and user reports, but the Flutter client cannot reliably answer:

- which uncaught exception terminated or corrupted the UI;
- whether Firebase initialization was unavailable;
- whether auth refresh logged the user out because of invalid credentials or a timeout;
- how often sockets reconnect or reconciliation fails;
- whether a notification token failed to register;
- cold-start, screen-load, frame, memory, or network timings;
- affected app/OS/device versions.

Any future telemetry must explicitly redact credentials, medical content, location, patient identity, and notification bodies.

## 15. Device compatibility readiness

Static inspection can establish minimum OS versions, requested permissions, lifecycle code, resource ownership, and whether native capabilities are declared. It cannot certify the broad device population requested.

Real-device validation is mandatory for:

- Android Keystore/iOS Keychain secure-storage persistence and upgrade behavior;
- PIN/biometric fallback, lockouts, enrollment changes, and shared-device use;
- FCM/APNs permission, delivery, token refresh, terminated launches, and OEM suppression;
- camera initialization, QR duplicate callbacks, permission denial/permanent denial, and background/foreground while scanning;
- GPS approximate/precise modes, services disabled, timeout, weak signal, and battery use;
- Google Maps key restrictions and renderer behavior;
- file/photo picker, PDF selection, large upload, cancellation, temp cleanup, and low-memory behavior;
- Android process death and iOS suspension during every write workflow;
- app upgrade with existing secure records/cache/token registration;
- notification and route entry after long delay/account switch;
- TalkBack, VoiceOver, accessibility scanners, large text, display scaling, RTL, keyboard, notches, orientation, and tablets/foldables.

Representative future categories should include: API 24/low RAM, Android 13 permission boundary, current Android/Pixel, at least one Samsung and one aggressive-background OEM, small and large iPhones at iOS 14/current iOS where practical, iPad/tablet, slow hardware, biometric/no-biometric devices, and constrained 3G/high-latency/lossy network profiles. This is a validation matrix recommendation, not a procurement decision.

## 16. Critical findings

| ID | Severity | Area | Finding | Evidence | Production impact |
|---|---|---|---|---|---|
| F-01 | P0 BLOCKER | Architecture/Other | **CONFIRMED —** Reachable urgent HOME care uses demo doctors and a fully mock consultation API | `patient_home_feed.dart:2020-2030`; `emergency_review_screen.dart:90-106`; `doctor_selection_screen.dart:20-31`; `doctor_matching.dart:92-139,250-320`; `consultations_api.dart:4-96`; `review_confirm_screen.dart:82-115`; `doctor_calling_screen.dart:43-61` | Patient is told an urgent request is confirmed although no server/doctor received it. Medical harm through false assurance. |
| F-02 | P1 CRITICAL | Network/Lifecycle | **CONFIRMED —** Any refresh exception clears the secure session | `auth_refresh_coordinator.dart:70-123`; `auth_repository.dart:310-334` | DNS/TLS/timeout/5xx during cold start or a 401 burst logs users out and destroys offline session recovery. |
| F-03 | P1 CRITICAL | Android/CI/CD | **CONFIRMED —** Android release is signed with debug signing config | `android/app/build.gradle.kts:55-60` | Not a valid production signing chain; insecure debug key and app-store/update continuity failure. |
| F-04 | P1 CRITICAL | Notification/iOS/Android | **CONFIRMED —** Repository cannot produce an evidenced push-capable mobile build and initialization failure is silent | Missing Firebase project files/Gradle plugin/entitlement/pipeline; `notification_push_coordinator.dart:30-57` | Urgent notifications may never register or arrive, with no client operational signal. |
| F-05 | P1 CRITICAL | Lifecycle/State | **CONFIRMED —** Persisted clinic-request operation is never restored and is cleared by entry | `request_submission_controller.dart:240-312`; `request_flow_entry_screen.dart:22-29`; `doctor_cabinet_entry_screen.dart:27-32`; only production-free call to `restoreInFlightOperation` is in tests | Process death during unknown POST outcome loses the idempotency identity; a fresh attempt can duplicate a care request. |
| F-06 | P1 CRITICAL | Testing/CI/CD | **CONFIRMED —** Full test suite fails and does not terminate | Full run `+1580 ~7 -13` at 6:07; exact reruns above | No trustworthy release regression gate; known contract/UI failures ship undetected. |
| F-07 | P2 HIGH | Observability | **CONFIRMED —** No production crash/error/performance/reconnect telemetry | No global error hooks or reporting dependency found | Severe mobile failures, silent push disablement, refresh logouts, and device-specific regressions are not diagnosable. |
| F-08 | P2 HIGH | CI/CD | **CONFIRMED —** No mobile CI/release pipeline or environment/signing separation | Only Docker web build; no mobile CI/Fastlane/flavors | Builds are manual, inconsistent, and can omit analysis/tests/config/capability checks. |
| F-09 | P2 HIGH | Network | **CONFIRMED —** No send timeout and generic auth replay is not stream/upload safe | `app_http_client.dart:47-56`; `auth_interceptor.dart:59-80` | Upload/write can hang on poor uplink; replayed consumed bodies can fail unpredictably. Runtime validation required for each multipart path. |
| F-10 | P2 HIGH | Realtime/Performance | **CONFIRMED —** Fixed endless five-second reconnect without backoff/jitter/telemetry | `authenticated_realtime_transport.dart:139-155,313-327` | Prolonged outages can create battery/network/server load; operators cannot quantify it. |
| F-11 | P2 HIGH | Navigation/Lifecycle | **CONFIRMED —** Critical/legacy routes depend on unchecked in-memory arguments and no route restoration | `main.dart:468-557`; `new_home_screen.dart:351-449`; no restoration IDs/API found | Stale/malformed route entry crashes; process death loses workflow context rather than reconstructing by ID. |
| F-12 | P2 HIGH | Localization/Accessibility | **CONFIRMED —** Three locales are declared but localization is used in only five files; hundreds of hardcoded strings remain | `app_localizations.dart`; 16 localization references across 5 files versus 493 static hardcoded text/label patterns | Arabic/French/English experiences are inconsistent; RTL, large text, and assistive output cannot be claimed. |
| F-13 | P2 HIGH | Cache/Security | **CONFIRMED —** Disk image cache is not explicitly cleared on logout/account switch | Cached network images in profile/family/clinic; no cache clear call found | Personal images may remain on shared devices after account transition. Policy/runtime validation needed. |
| F-14 | P3 MEDIUM | Memory/Performance | **CONFIRMED —** Text controllers are constructed in `build` | `edit_medical_data_screen.dart:727-755,843-848` | Rebuild churn, cursor reset risk, and unmanaged controller lifetime in medical document editing. |
| F-15 | P3 MEDIUM | Security/Cache | **CONFIRMED —** Bundled tracked `.env` and uncleaned temp images | `pubspec.yaml:98-112`; `.env`; `file_picker_service.dart:24-42` | Client config is extractable; personal image artifacts can remain until OS cleanup. Values must never be treated as secrets. |
| F-16 | P3 MEDIUM | Testing/Other | **CONFIRMED —** Analyzer has 389 issues | `flutter analyze`: 0 errors, 31 warnings, 358 infos | Signal-to-noise hides meaningful async/context/control-flow problems and cannot serve as a clean CI gate. |
| F-17 | P2 HIGH | Memory/Network | **CONFIRMED —** Medical-document upload buffers the complete PDF/image and has no client size bound or cancellation | `medical_documents_screen.dart:181-195,263-303`; `DocumentsApi.startUpload()`/`upload()` in `documents_api.dart:240-300` | A large selection can create substantial transient memory on low-end phones and an upload cannot be explicitly cancelled during poor connectivity. |

### Detailed validation and suggested direction

#### F-01 — Reachable synthetic urgent-home request

- **Severity/confidence:** P0 BLOCKER / CONFIRMED
- **Area:** Architecture, State, Network, Other (medical safety)
- **Path:** Patient home invokes `/emergency-step0`; home urgent mode invokes `/emergency-step1`; review routes to `/doctor-selection`. `DoctorSelectionScreen` defaults to `DemoDoctorMatchingSource(createDemoUrgentDoctors())`, whose timers emit accepted demo doctors. `ReviewConfirmScreen` invokes `ConsultationsApi`, whose `createConsultation`, `getConsultation`, completion, prescription, and list methods all fabricate objects and never use Dio. The next screen displays “Demande Confirmée” and automatically moves toward an arrival UI.
- **Consequence:** A patient can rely on care that was never requested. This is materially worse than a generic missing feature because the UI positively confirms a nonexistent urgent response.
- **Validate:** Release build, patient -> urgent request -> at home -> complete intake -> send -> select displayed doctor -> confirm. Observe no HTTP call while success/confirmation is shown.
- **Before production:** Yes, absolute blocker.
- **Suggested direction:** Gate/remove this production route until it is backed by the authoritative urgent-home API and recovery model. Do not preserve a success UI without server-created identity. Reuse the good authoritative patterns already present in urgent cabinet/home doctor controllers; no architecture-library change is implied.

#### F-02 — Refresh network failures invalidate sessions

- **Severity/confidence:** P1 CRITICAL / CONFIRMED
- **Area:** Network, Lifecycle
- **Consequence:** A user with a still-valid refresh token is logged out when mobile data changes, DNS fails, TLS handshake times out, or refresh returns a transient server error. At cold start with an expired access token this also deletes the only restorable session.
- **Validate:** Store an expired access token with unexpired refresh token, block the refresh endpoint or inject a Dio timeout, launch, then inspect secure session/auth state.
- **Before production:** Yes.
- **Suggested direction:** Classify refresh responses: invalidate only on authoritative invalid/expired/revoked credentials; retain session and surface recoverable/offline auth state for transport/5xx failures. Preserve single-flight refresh and one-replay fencing.

#### F-03 — Debug signing in release

- **Severity/confidence:** P1 CRITICAL / CONFIRMED
- **Area:** Android, Security, CI/CD
- **Validate:** Gradle signing report or completed release AAB certificate inspection.
- **Before production:** Yes.
- **Suggested direction:** Establish protected upload/release signing outside source, Play App Signing ownership, reproducible CI injection, and certificate continuity/rotation procedure.

#### F-04 — Push capability is external but no external setup is evidenced

- **Severity/confidence:** P1 CRITICAL / CONFIRMED for repository state; actual deployed environment remains UNKNOWN
- **Area:** Notification, Android, iOS, CI/CD
- **Consequence:** The binary can silently fall back to REST/realtime only. Those mechanisms are unavailable while the app is suspended/terminated, precisely when urgent push matters.
- **Validate:** Complete signed builds with production-injected Firebase config; verify native token, backend token registration, foreground/background/terminated delivery, data-only message behavior, logout/unregister, reinstall/token rotation, and APNs environment on physical devices.
- **Before production:** Yes.
- **Suggested direction:** Make Firebase/capability injection and a push smoke test mandatory release inputs; emit a privacy-safe health signal when initialization/registration fails. Add only the background behavior the product contract requires.

#### F-05 — In-flight clinic request recovery is unwired

- **Severity/confidence:** P1 CRITICAL / CONFIRMED
- **Area:** Lifecycle, State, Network
- **Consequence:** If POST reaches the server but the process dies before response/cleanup, the secure record exists. On next deliberate entry, `beginNewRequest()` generates a new ID and clears it, defeating duplicate prevention.
- **Validate:** Delay POST response after server commit, kill process, relaunch and enter clinic request; inspect the stored operation before/after entry and resulting server records.
- **Before production:** Yes.
- **Suggested direction:** Restore/account-validate the record before any fresh operation is minted, present explicit interrupted/verify/retry UX, and reconcile by operation ID. Preserve the existing secure schema, same-ID retry, and no-auto-submit principle.

#### F-06 — Test gate fails/hangs

- **Severity/confidence:** P1 CRITICAL / CONFIRMED
- **Area:** Testing, CI/CD
- **Consequence:** Both behavioral regressions and a test deadlock are present; there is no deterministic release gate.
- **Validate:** Commands in the diagnostics appendix.
- **Before production:** Yes.
- **Suggested direction:** Triage each failure against intended frozen behavior, eliminate test non-termination, then enforce deterministic analysis/test/build stages. Do not “fix” by weakening valid clinical assertions.

#### F-07 through F-17

| ID | Exact component/function | Runtime validation | Before production? | Suggested direction (not implementation) |
|---|---|---|---|---|
| F-07 | `main()`/root error boundary; notification and realtime coordinators; no `FlutterError.onError`, `PlatformDispatcher.instance.onError`, zone handler, or reporting SDK | Inject handled/unhandled Flutter, isolate, API, push-init, and reconnect failures in a privacy-safe staging build and verify incident context | Yes | Define redacted crash/error/performance/reconnect signals with release/version/device context and explicit PHI exclusions. |
| F-08 | Repository CI/release configuration; `AppEnvironment._normalizeBaseUrl()` | Produce signed staging and production artifacts from a clean runner and inspect endpoint, capabilities, version, certificate, and test provenance | Yes | Establish pinned, protected mobile pipelines with explicit environment allowlists, Firebase/capability inputs, dependency lock enforcement, analysis, tests, and artifact verification. |
| F-09 | `AppHttpClient.create()` options; `AuthInterceptor.onError()` request replay | Throttle/stall multipart upload, expire access token mid-upload, and observe cancellation/replay/server results on physical devices | Yes for critical writes/uploads | Add bounded send/upload behavior and make replay eligibility explicit by body type and idempotency contract; do not blindly retry writes. |
| F-10 | `AuthenticatedRealtimeTransport._scheduleReconnect()` and connection lifecycle | Run long outage, rapid network transitions, background/foreground, token change, and reconnect storms; measure attempts, battery, duplicates, and REST reconciliation | Yes | Use lifecycle/connectivity-aware bounded exponential backoff with jitter and operational metrics while preserving authoritative REST reconciliation. |
| F-11 | `main.dart` route factory and `_PatientNavigator` in `new_home_screen.dart` | Launch every identifier route with missing/malformed/stale args, kill/restart mid-flow, and test notification entry after logout or entity closure | Yes for critical paths | Validate route inputs and rebuild critical destinations from opaque identifiers plus current authorization/server state. |
| F-12 | `AppLocalizations`, route/screen user-facing text, semantics and fixed layouts | Run all critical journeys in en/fr/ar with RTL, 200% text, TalkBack, VoiceOver, keyboard, and contrast tooling | Yes for claimed supported locales/accessibility | Complete localization/plural/date/error coverage and semantic/focus/touch-target validation without redesigning the approved UI. |
| F-13 | `CachedNetworkImage` use across profile/family/clinic and logout/account-switch flow | Log in as two accounts on a shared device, inspect offline/cache behavior after logout, and apply the approved healthcare retention policy | Policy decision and validation required before production | Define a deliberate personal-image cache policy and account-bound invalidation; avoid claiming a leak until runtime evidence exists. |
| F-14 | `EditMedicalDataScreen.build()` | Rebuild while typing/editing multiple documents and profile allocations/selection behavior | No, unless user-visible corruption is reproduced | Move controller ownership to a stable disposable lifecycle while preserving screen behavior. |
| F-15 | `pubspec.yaml` asset declaration, `.env`, `FilePickerService.compressImage()` | Extract the release asset, validate Cloudinary/backend abuse controls, upload/cancel repeatedly, and inspect temp retention | Secret/abuse policy: yes; temp cleanup: planned hardening | Treat bundled values as public configuration, enforce server-side controls, and define bounded temp-file cleanup. |
| F-16 | Repository-wide analyzer output | Re-run analyzer from a clean pinned SDK and classify all 31 warnings plus high-risk async/control-flow infos | Yes as a deterministic gate | Burn down actionable diagnostics and enforce an agreed clean baseline; do not bulk-format or suppress valid warnings. |
| F-17 | `_pickDocumentFile()`, `_uploadDocument()`, `DocumentsApi.startUpload()` and `upload()` | Select files below/at/above the backend limit on low-memory devices, throttle uplink, background/kill the app, and measure memory plus server/idempotency outcome | Yes for supported document upload | Enforce the agreed limit before full buffering where platform APIs permit, expose explicit cancellation/progress, and retain idempotency for ambiguous outcomes. |

All eleven entries have **CONFIRMED** static confidence. Statements that depend on device behavior remain explicitly unproven until the validation column is executed.

## 17. Top production blockers

Only confirmed launch blockers are listed; the table is not padded to ten.

1. **F-01 — P0:** urgent HOME request can confirm care that was never sent.
2. **F-02 — P1:** temporary network failure during token refresh deletes the session.
3. **F-03 — P1:** Android release uses debug signing.
4. **F-04 — P1:** no evidenced push-capable mobile build configuration; failure is silent.
5. **F-05 — P1:** process-death idempotency recovery is implemented but not wired.
6. **F-06 — P1:** the test suite has at least 13 failures and hangs.

## 18. Things that are already well designed

Preserve these behaviors while hardening:

- One shared production `AppHttpClient`, token store, refresh coordinator, and authenticated realtime transport are constructed at bootstrap.
- Refresh is single-flight and each request is replayed at most once, preventing a 10x refresh stampede and infinite 401 loops.
- Modern write flows use stable idempotency/operation keys instead of blind retry; clinic and urgent-cabinet requests explicitly model unknown outcomes.
- Search/detail/controllers often use Dio cancellation and generation/owner checks, preventing stale async results from overwriting newer account/query state.
- Scheduled-care and notification WebSocket messages are invalidation signals, not authoritative medical state. Reconnect/foreground paths fetch REST authority.
- Urgent-cabinet patient recovery is account-scoped, identifier-based, and backend-authoritative. Notification taps re-fetch and authorize before navigation.
- Realtime bearer tokens are in STOMP CONNECT headers, not URLs.
- Secure session storage is a versioned record with legacy migration; token-bearing `toString` output is redacted.
- Clinic-selection persistence is a hint and is revalidated with the backend.
- Logout/account switching clears a broad set of session-scoped controllers and stops realtime/push.
- Release API URL fails closed when the Dart define is absent; release does not silently use localhost.
- No production Dio payload logger, TLS bypass, release cleartext opt-in, or background-location permission was found.
- Modern urgent-cabinet discovery uses authoritative backend repositories in production and exposes fixtures only through explicit debug/test injection.
- Many controller and resource ownership paths have explicit dispose/cancel behavior, and the test suite is unusually broad at unit/widget level even though it is not currently green.

## 19. Technical debt that can wait

These should not displace the blockers above:

- Splitting very large widgets/controllers after profiling and ownership analysis.
- Replacing deprecated `withOpacity` calls and low-value analyzer info diagnostics.
- Removing unused `shared_preferences` and discontinued `js` only after dependency-impact review.
- Consolidating legacy model/API duplicates after production routes no longer reference them.
- Adding exponential realtime backoff after correctness and push are operational, provided battery testing does not show a launch-critical issue.
- Improving temp-file cleanup and image-cache policy once product/privacy requirements are explicit.
- Refining hardcoded UTC+1 scheduling assumptions into server-provided timezone handling; Tunisia is the current product context, but the client should not silently generalize.
- Optimizing large images/layouts only after profile-mode evidence.
- Adding R8/resource shrinking after release correctness and plugin compatibility validation.

Legacy mock APIs are not harmless cleanup if a production route references them. Those references must be gated before the remaining unused code can be treated as deferred deletion.

## 20. Unknowns requiring runtime validation

NOT PROVABLE FROM STATIC INSPECTION — runtime validation required:

- Cold/warm startup and time to usable patient/doctor/clinic screen.
- Frame jank and input latency on low-end devices, maps, directories, large profile/medical screens, and RTL/large text.
- Memory growth across long sessions, navigation cycles, scanner/maps, image cache, and uploads.
- Android OEM background socket/push behavior and iOS suspension behavior.
- FCM/APNs delivery, token rotation, notification collapse/duplication, and delayed notification entry.
- Wi-Fi/mobile transitions and long packet-loss periods for Dio and STOMP.
- Android process death/iOS termination at every critical write boundary.
- Camera/QR duplicate callbacks, expired QR, permission denial, and resume.
- Approximate/precise GPS, disabled services, indoor timeouts, and battery cost.
- Keychain/Keystore access after OS/app upgrades, biometric changes, restore/backup, and shared devices.
- Actual merged Android manifest permissions/backup policy because the release build did not finish.
- iOS signing, entitlements, provisioning, App Store validation, and APNs environment.
- AAB/IPA size, symbols, minification, and store acceptance.
- Contrast, semantics tree, focus order, touch targets, TalkBack, VoiceOver, and switch/keyboard access.
- Backend contract behavior for idempotency, notification token transfer, multiple devices, malformed list elements, and stale identifiers.

## 21. Recommended validation plan

1. Freeze release distribution and reproduce F-01 in a release-like build while capturing network traffic; prove the urgent-home success has no backend call.
2. Remove/gate every production path to synthetic clinical success, then inventory all remaining `mock`, `demo`, `fixture`, `simulate`, and `devAutoComplete` references reachable from `main.dart`.
3. Build contract tests for refresh outcomes (invalid credential versus timeout/DNS/TLS/5xx) and process-kill the app during clinic request submission to verify same-ID reconciliation.
4. Establish deterministic static-analysis and test execution. Resolve all 13 full-run failures and the `review_screen_test` hang; rerun with CI-like concurrency and timeouts.
5. Establish mobile release CI inputs: pinned Flutter, locked pub resolution, production Dart defines, Firebase project files/capabilities, protected Android signing, iOS provisioning, analysis, tests, and release builds.
6. Prove push on physical Android/iOS in foreground/background/terminated states, including Android 13+ permission, APNs, logout, reinstall, token rotation, and stale notification authorization.
7. Add privacy-safe crash/error/reconnect/push-registration telemetry and verify redaction before broad testing.
8. Run poor-network scenarios: startup offline, expired access token, 401 burst, request timeout, unknown write outcome, Wi-Fi/mobile handoff, reconnect storm, and recovery after hours.
9. Run process-death and upgrade matrices for auth, clinic request, scheduled care, urgent cabinet, active consultation, QR access, and notification entry.
10. Run profile-mode physical-device performance/memory/battery measurement on the slowest supported class; measure rather than infer.
11. Run permissions/plugin matrices for maps, GPS, camera, QR, file/photo picker, secure storage, biometric, and notifications.
12. Complete localization/accessibility audits with English/French/Arabic, RTL, 200%+ text, TalkBack, VoiceOver, scanners, and keyboard/focus testing.
13. Only after the above, expand the OEM/OS/device certification matrix and staged rollout with observability/rollback thresholds.

## 22. Proposed future workstreams

A. **Clinical correctness and synthetic-path removal** — ensure every success/assignment/medical transition is backed by authoritative server state.  
B. **Lifecycle and recovery** — process death, unknown outcomes, route reconstruction, upgrades, and session recovery.  
C. **Authentication/network resilience** — refresh error classification, bounded upload/send behavior, poor-network UX, and safe replays.  
D. **State/source-of-truth convergence** — eliminate production references to legacy mock state and document domain authority.  
E. **Cache/privacy** — image/temp retention, logout/account switching, shared-device policy, and persisted-location review.  
F. **Realtime and notifications** — backoff, FCM/APNs capabilities, background behavior, token lifecycle, and authoritative reconciliation.  
G. **Release engineering** — toolchain pinning, environments, signing, CI gates, artifact provenance, and store checks.  
H. **Observability** — redacted crash/error/network/reconnect/push/performance signals.  
I. **Performance/resource validation** — startup, frames, memory, CPU, battery, app size, and large file/image behavior.  
J. **Accessibility/localization/device certification** — locale completeness, RTL, semantics, text scale, assistive technologies, OEM/OS matrix.  
K. **Test strategy** — restore deterministic unit/widget tests and add backend-connected/device integration journeys.

## 23. Final production readiness scorecard

| Area | Score /10 | Evidence | Main risk |
|---|---:|---|---|
| Architecture | 4 | Strong modern feature layers coexist with reachable synthetic clinical layers | Urgent-home production route fabricates success. |
| State management | 5 | Clear modern controllers and owner/generation guards | Legacy mock state and unwired recovery create contradictory truth. |
| Networking | 5 | Shared Dio, single-flight refresh, typed failures, idempotency | Refresh transport errors delete session; no send timeout. |
| Caching | 4 | Deliberately narrow secure persistence | No offline data strategy; image/temp privacy and in-flight restore gaps. |
| Lifecycle/recovery | 4 | Foreground resync and urgent-cabinet recovery are strong | Clinic restore unwired; generic route state lost. |
| Realtime | 7 | Single owned connection, dedup/cleanup, REST reconciliation | Fixed endless reconnect and no production metrics/device proof. |
| Notifications | 2 | Good payload validation and authoritative re-fetch design | Native project capability/config/pipeline absent; silent disablement. |
| Performance readiness | 4 | Some lazy/cancellation design and no fabricated benchmarks | No profile harness; very large rebuild surfaces; release artifact absent. |
| Memory/resource management | 6 | Most controllers/timers/subscriptions disposed | Controllers in build, temp files, caches need validation. |
| Android | 3 | Modern API targets, no release cleartext, foreground permissions | Debug release signing, unverified merged permissions/backup, no app links. |
| iOS | 3 | iOS 14, reasonable usage strings, no ATS bypass | No push entitlement/config/background modes or signed build proof. |
| Security/privacy | 5 | Secure tokens/app lock, no TLS bypass or sensitive Dio logger | Debug signing, bundled config, disk images/temp files, no formal log/cache policy. |
| Testing | 4 | Broad 119-file unit/widget suite | 13 failures, hang, no integration/device suite. |
| Accessibility | 3 | Some Semantics/tooltips and keyboard test | No complete semantics/text-scale/manual assistive validation. |
| Localization | 3 | English/French/Arabic delegate and Arabic map exist | Localization used in only five files; extensive hardcoded copy. |
| Observability | 1 | Ad hoc console logs only | No crash/error/performance/reconnect/push diagnostics. |
| Release safety | 2 | Locked dependencies and release API URL fail-closed | No mobile CI/flavors/signing/config gates; tests not green. |

**Overall production readiness: 3.5/10**

This is intentionally blocker-weighted rather than a simple arithmetic average. A healthcare client that can falsely confirm an unsent urgent request cannot receive a moderate readiness rating because unrelated modules are well engineered.

## Diagnostics and command record

### Commands executed

- `git status --short --branch`, `git log -1 --oneline --decorate`, and read-only file/history inspection. Initial and final tracked status were clean on `deployrailway`; after diagnostics and before this report, no tracked source change existed.
- Repository-wide `rg`, `find`, `wc`, `sed`, `nl`, and manifest/project inspection for architecture, routes, state owners, clients, persistence, lifecycle, resources, localization, security patterns, tests, CI, Android, and iOS.
- `flutter --version`: Flutter 3.41.2 stable, Dart 3.11.0, DevTools 2.54.1.
- `dart --version`: Dart 3.11.0.
- `flutter doctor -v`: returned exit 0 but reported Android license status unknown and missing iOS 27.2 simulator runtime; no Android/iOS device was connected.
- `flutter analyze --no-pub`: exit 1, 389 issues = 0 errors, 31 warnings, 358 infos. Examples include async context use, control flow in `finally`, unused code/imports, and deprecated APIs.
- `flutter pub outdated --no-dev-dependencies --no-dependency-overrides`: read-only inspection. 77 locked dependencies were upgradable, 27 direct/transitive constraints were behind a resolvable version, and `js` plus the transitive `flutter_secure_storage_macos` package were reported discontinued. Version age alone was not classified as a defect.
- `flutter test --reporter compact`: reached `+1580 ~7 -13` and did not complete; interrupted after 6:07 while `review_screen_test.dart` remained active.
- `flutter test test/core/api/documents_api_test.dart --reporter expanded`: 1 pass, 1 failure.
- `flutter test test/patient_request_status_matrix_test.dart --reporter expanded`: 7 passes, 4 failures.
- `flutter build appbundle --release --no-pub --dart-define=OMNICARE_API_BASE_URL=https://audit.invalid`: AOT/icon tree shaking and native compilation progressed, but Gradle `bundleRelease` emitted no further progress and was interrupted after 460.1 seconds; exit 130, no AAB produced. The URL was deliberately non-routable and the app was not run.
- Official Flutter/Firebase/Android/Apple documentation lookup for the baseline links cited above.

### Commands/tests not completed and why

- Full Flutter tests: did not terminate and already had 13 failures; interrupted to avoid an indefinite run. The exact complete failure list therefore remains unknown.
- Android release AAB: did not complete within 460 seconds and produced no artifact; interrupted. The checked-in signing defect is independently proven by Gradle source.
- iOS release build/sign/archive: not attempted because there is no Firebase plist/push entitlement/provisioning evidence and the local doctor reports the iOS simulator runtime missing. A no-codesign compile would not validate the missing production capabilities.
- Physical-device, integration, profile, memory, battery, notification, GPS, camera/QR, biometric, process-death, upgrade, accessibility, and network-transition tests: no Android/iOS device or integration harness was available, and static inspection cannot substitute for them.
- Coverage: not run; the request prohibits unsupported claims, and the non-terminating failing suite could not produce meaningful coverage.

## Important dependency snapshot

| Package | Locked version observed | Critical role / implication |
|---|---:|---|
| `provider` | 6.1.x constraint | Root/feature DI and ChangeNotifier state; not itself a defect. |
| `dio` | 5.9.2 | All modern REST/auth; centralized in `AppHttpClient`. |
| `flutter_secure_storage` | 9.2.4 | Tokens, app lock, request/clinic recovery; native upgrade tests required. |
| `firebase_core` / `firebase_messaging` | 5.0.0 / 17.0.0 | Critical push stack; native config/capability absent from repository. |
| `flutter_local_notifications` | 17.2.4 | Foreground/local alerts; Android merged permission must be verified. |
| `stomp_dart_client` | 3.0.x constraint | Scheduled-care/notification realtime over SockJS/STOMP. |
| `geolocator` / `google_maps_flutter` | 10.1.1 / 2.14.2 | Foreground GPS/maps; real-device permissions/battery/key tests required. |
| `mobile_scanner` | 7.4.2 | Medical QR camera path; real-device lifecycle/duplicate-scan tests required. |
| `image_picker` / `file_picker` / image compression | 1.2.1 / 8.3.7 / 2.4.0 | Avatar/document selection; upload interruption and temp cleanup risk. |
| `cached_network_image` | 3.4.1 | Disk-backed personal/profile image cache without explicit account purge. |
| `shared_preferences` | 2.5.4 | No app use found; dependency cleanup can wait. |
| `js` | 0.6.7 | Reported discontinued; web-related, not by itself a mobile production blocker. |

## Decisions explicitly NOT made by this audit

This inspection does **not** decide:

- whether Provider remains;
- whether ChangeNotifier remains;
- whether Riverpod, BLoC, Redux, GetX, or another state library is adopted;
- whether Clean Architecture is introduced;
- whether local database caching is introduced;
- which cache technology to use;
- whether navigation changes;
- whether the networking layer is rewritten;
- whether feature folders are reorganized;
- whether any UI is redesigned.

Those decisions should be made only after the confirmed correctness, lifecycle, release, and observability failures are understood and prioritized. The approved UI/UX remained frozen during this audit.
