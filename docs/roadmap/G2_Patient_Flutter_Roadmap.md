# OmniCare — G-2 Patient Flutter: backend wiring roadmap
_Owner: CTO (Mechergui) · Architect: Claude · v1.2 · 2026-11-10 23:00 · Status: ACTIVE (live status in §0.1; CTO decisions in §4 pending; architect decisions in §4.1 applied)_
_Sources: Production-Readiness Inspection 2026-11-10, Consultation Deep Inspection 2026-11-10, Status Baseline 2026-11-10, ADR-003 v1.1 (Accepted), **G-2 P0 inventory** (`OmniCare-App/docs/reports/G2/G2-P0-inventory.md`)._
_Repo copy: `OmniCare-App/docs/roadmap/G2_Patient_Flutter_Roadmap.md` (Claude Code reads this one). The claude.ai project copy is the master; re-copy after every version bump._

---

## 0. Goal card

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

---

## 0.1 Status board (updated 2026-11-10 23:00)

**In one line:** the patient app is fully inspected and the plan is set; no code has changed yet. Next is the first fix (Phase 1a-1, booking slot +1 h).

### Deliverables
| # | Deliverable | Status | Evidence |
|---|---|---|---|
| 1 | Detailed roadmap (consultation excluded) | ✅ done | this file, v1.2 |
| 2 | Patient app connected to the backend, no UI redesign | 🔨 building: inspection done, 0 fixes delivered | P0 inventory |
| 3 | A report for every step | 🔨 building: 1 report | `docs/reports/G2/G2-P0-inventory.md` |
| 4 | Prompts enforcing design patterns, clean code, complexity/memory, official docs | ✅ done | §5 standards, §6 report format, §7 Prompt #1 |

### Phases
| Phase | Content | Status |
|---|---|---|
| P0 | Read-only inventory | ✅ done (2026-11-10) |
| 1a-1 | Booking slot sent +1 h (C1, live P0) | ▶️ **next**: prompt ready |
| 1a-2 | Blood-type sentinels + missing save error (C3) | ⏳ |
| 1a-3 | Urgent-cabinet tolerant parsing, query length (C4–C6, C8) | ⏳ |
| 1a-4 | `NO_SHOW` status (C10); C11 recorded as a design gap | ⏳ |
| 1a-5 | Push semantic type, backend `notification` module (F7) | ⏳ |
| 1b | Foundation: build config, one error parser (5 shapes), logger, Tunis time, French default, mock cut-off guard | ⏳ |
| 1c | Honest states: hide invented home/clinic/doctor content; delete unreachable code | ⏳ |
| 2 | Auth and account (password recovery needs Spring + security review) | ⏳ |
| 3 | Medical data via `/profile/medical-data` (MRS) | ⏳ blocked by decisions #1, #2 |
| 4 | « Dossier médical » real | ⏳ after 3 |
| 5 | Documents (re-bind screen, MRS-02 contract) | ⏳ |
| 6 | Push / FCM | ⏳ blocked by decision #4 |
| 7 | Appointments clean-up | ⏳ |
| 8 | Privacy controls | ⏳ |
| 9 | Ma Santé | ⏳ blocked by decision #3 |
| 10 | Urgent care, patient side | ⏳ blocked by decision #3 |
| 11 | Release hardening | ⏳ (#5 bundle IDs) |
| 12 | Verification + G-2 gate | ⏳ |

### What we did (2026-11-10)
1. Roasted the P5 consultation roadmap. Consultation work moved to the G-1 chat; G-2 = patient Flutter app.
2. Wrote this roadmap (v1.0), the engineering standards and Prompt #1.
3. Ran the P0 inventory: booking +1 h, fixture medical record, Ma Santé losing edits, orphaned documents screen, invented home/clinic content, 13 unrouted notification types, 5 error shapes.
4. Updated the plan to v1.1: Phase 1a (live fixes) and 1c (honest states) added; 13 inventory questions decided (§4.1); machine-checkable gate (§8).

### Next
1. Run Prompt 1a-1 (booking slot +1 h), then review its report.
2. Then 1a-2 → 1a-5, one prompt at a time, each reviewed before the next.
3. Then Phase 1b, then 1c.

### Waiting on the CTO (§4)
#1 MRS as source of truth · #2 medications read-only · #3 V1 scope (Ma Santé in, urgent out) · #4 Firebase ownership + push payload policy · #5 bundle IDs. None blocks Phase 1.

### New issues found
- **APP-C1 (P0 candidate):** patient booking slot sent +1 h (live).
- Parking lot: clinic/doctor backend fields (G12, G13); schedule-proposal accept/reject UI (C11); forgot-password and account-deletion UI (need design).

---

## 1. Scope and boundaries

### 1.1 In scope
- `OmniCare-App` patient side (everything under `lib/` except `features/doctor/**`).
- The Spring and MRS endpoints the patient app needs, **patient-side read/write paths only**.

### 1.2 Out of scope: owned by the consultation chat (G-1). Do not edit these.
| Repo | Paths |
|---|---|
| OmniCare-App | `lib/features/doctor/**`; `lib/features/patient_passport/sharing/**` (read-only for us until G-1 lands its access-request work) |
| OmniCare-FrontEnd | everything (Angular is not part of this goal) |
| OmniCare-BackEnd | `consultation/`, `clinicalrecord/`, `clinicalorder/`, `medicalsharing/`, `mrs/projection/`, doctor controllers in `prescription/` and `artifact/` |
| omnicare-mrs | write paths in `records` (consultation record), `completion/`, `workspace/`, `qr/`, `orders/`, `directconsent/`, `artifacts/` |

**Shared contracts** (we may add **read-only, additive** routes; we must announce them to the consultation chat before merging): MRS `artifacts` (patient download of finalized artifacts), MRS `records` LIFE_SAFETY schema (three-state « Aucune connue »).

### 1.3 What "don't touch the current UI" means
| Allowed | Not allowed |
|---|---|
| Binding existing widgets to real data | Changing layout, spacing, colors, typography, theme, navigation structure |
| Loading / empty / error states **using existing components and styles** | New visual components or redesigned screens |
| Replacing English or fixture text with French copy (via ARB) | Adding screens. If a function has no screen, **stop and report**: design goes through Figma first |
| Hiding the entry point of a feature that cannot work yet | Moving features between tabs |
| Non-visual security flags (FLAG_SECURE, allowBackup) | |

### 1.4 Parallel-work rule (two chats, same repos)
- MRS and Spring changes from G-2 go through review (omnicare-code-review), because the consultation chat touches the same repos.

---

## 2. Current state of the patient app (from the 2026-11-10 inspections)

| Area | Real today | Fake / broken / missing |
|---|---|---|
| Auth (PAT-01) | email+password, phone OTP code exists, devices, phone change | phone OTP off by default (`app_environment.dart:19-22`), Google button always shown and web-only config, `ForgotPasswordScreen` fakes success, English errors |
| Family (PAT-02) | DONE: CRUD, members are records | 1 backend test, no ownership test |
| Profile (PAT-04) | profile, avatar, account | medication search uses a ~10-item mock (`core/api/medications_api.dart:46`); `photoUrl` accepts any string |
| Dossier médical (PAT-03) | — | **fixture "Sarah Ben Ahmed" for everyone** (`patient_passport_screen.dart:38`); `MedicalDataEditorScreen` makes no API call; documents 404 (MRS-02); raw download 403 by design |
| Ma Santé (PAT-05) | tab = passport card + documents | no backend (`BEJ/masante/` empty) |
| Appointments (PAT-06) | DONE: booking requests, slots, cancel, scheduled-care screens | notification times in UTC (1 h off); `ReservationProvider` always `useMock()`; legacy « Mes demandes » path |
| Urgent cabinet (PAT-07) | client flow complete, ~25 tests | cannot run in production (backend dev-only mode); app gate hardcodes synthetic flags `true`; Idempotency-Key length mismatch; `amountTnd` sent as double |
| Urgent home (PAT-08) | — | « Envoyer » goes to `/clinical-request-unavailable`; backend matching unscheduled |
| Sharing (policy, QR, approve) | real APIs wired | passport body around them is the fixture |
| Notifications | inbox, unread count, mark read, STOMP invalidation | **push dead**: no Firebase config, no background handler, channels lazy, tap routing only knows booking/appointment/urgent-cabinet |
| Cross-cutting (see §2.1 for the P0-verified version) | 1,709 tests green | default `Locale('en')`, ≥186 English strings, i18n map used in 6 files; `.env` bundled in APK (Maps key); release signed with debug key; no crash reporting; `debugPrint` in release; ~13.9k LOC dead legacy screens; `lib/mock_data` imported by "real" APIs; 82 `DateTime.now()`, Tunis offset hardcoded |

### 2.1 P0 inventory: verified facts that changed the plan (IDs refer to the P0 report)
- 276 patient files reachable from `main.dart`; ~21,000 patient LOC unreachable (87 files).
- **F1/C1 (P0):** booked slot is POSTed 1 h late: `toTunisWallClock` value is sent as the UTC start (`doctor_directory_mapper.dart:107-108,226-227` → `patient_booking_controller.dart:261-263`). Tests bypass the mapper.
- **F4/G2:** `/api/v1/passport/**` is denied by `anyRequest().denyAll()`. Good for DATA-01: keep it denied.
- **G4:** `GET/PATCH /profile/medical-data` (MRS-backed) exists and the app never calls it → Phase 3 is mostly app wiring.
- **C2/C3:** Ma Santé sends `medicalInfo` (silently dropped) and blood-type sentinels `'-'`/`'IDK'` (400, no catch).
- **C4–C6:** urgent-cabinet enum/phase drift makes the whole snapshot fail to parse. **C10/C11:** `NO_SHOW` and schedule-proposal actions dropped.
- **F6:** the real `MedicalDocumentsScreen` works but is reachable only from orphan routes.
- **F7:** FCM data carries the template alias type → 3 booking push taps fail; 13 patient types unrouted.
- **F10:** home feed shows invented network stats, a hardcoded referral code and a default first name; clinic detail shows invented doctors, hours and insurers.
- **f.1:** the backend has **five** error shapes (not two). 9 places show server text to patients.
- Idempotency keys are already compliant everywhere (UUIDv4, 36 chars). No rework needed.
- Patient artifacts per consultation already exist (`/patient/consultations/{cid}/artifacts`), but the PDF is held fully in memory with no cap.

---

## 3. Phases

Sizes: S ≈ ≤3 dev-days · M ≈ 1–2 weeks · L ≈ 2–4 weeks (one mid-level dev, rough estimate).
Each phase = one or more Claude Code prompts, each producing a report (§6).

### Phase 0 — Inventory and safety net (read-only) · S
**Objective:** one factual map of every patient screen and where its data comes from, before any change.
- Screen → view model/provider → repository/API class → HTTP endpoint → Spring controller exists? → data source class (REAL / MOCK / FIXTURE / STATIC / DEAD) → reachable from production `main.dart`?
- Import graph of `lib/mock_data`, `lib/demo`, `main_*.dart` into production code.
- DTO ↔ Spring DTO contract check for every wired endpoint (field names, types, enums, nullability).
- English/hardcoded strings per screen; `DateTime.now()` call sites; `debugPrint` call sites.
- Tests per feature.

**Done when:** `docs/reports/G2/G2-P0-inventory.md` exists and the CTO has reviewed the proposed wiring order. **No source change.** → Prompt #1 in §7.

### Phase 1a — Live correctness fixes on already-real flows · S–M · **starts now**
Real users hit these today; no UI change. One prompt per item, in this order:
1. **1a-1 C1:** booking slot +1 h (P0). Keep the server instant canonical; Tunis wall clock only for display.
2. **1a-2 C3:** blood-type sentinels `'-'`/`'IDK'` → the backend's `unknown`/blank; add the missing error handling with a French message on `EditMedicalDataScreen` save.
3. **1a-3 C4–C6, C8:** urgent-cabinet tolerant parsing (unknown enum values → `unknown`, never a FormatException for the whole snapshot); query max length 120 on the client.
4. **1a-4 C10:** `NO_SHOW` status with a French label and terminal semantics. C11 (schedule-proposal accept/reject) has **no UI** → recorded as a design gap, not built.
5. **1a-5 F7 (backend, `notification` module):** FCM data carries the **semantic** type (`type`) and the template type separately (`templateType`); the app routes on `type`.

Each fix: a contract test that builds the payload through the **real** mapper/parser from a recorded server JSON.

### Phase 1b — Foundation layer (no visible change) · M
Everything later depends on this. No feature is wired in this phase.
1. **Build config:** `--dart-define-from-file` per environment (`env/dev.json`, `env/staging.json`, `env/prod.json`; real files git-ignored, `*.example.json` committed). Release build **fails** if `OMNICARE_API_BASE_URL` is missing (MOB-06). Remove `.env` from `pubspec.yaml` assets (SEC-02; the key itself is rotated in WS-0).
2. **HTTP layer (one client):**
   - one typed `ApiFailure` parser covering **all five** backend error shapes (P0 §f.1): `ErrorResponse{code,…}`, the session-limit map, `ProblemDetail`+`errorCode`, `ProblemDetail`+`code`, and the security problem map. Code key = `errorCode ?? code`;
   - `code` → French message catalog (ARB). **Never display server `message`/`detail` text**: remove the 9 sinks listed in P0 §f.3;
   - `Idempotency-Key`: already UUIDv4 everywhere (P0 §d.4). Consolidate into one helper; no behaviour change;
   - timeouts; retry only network/5xx on idempotent-keyed requests, max 3, exponential backoff with jitter;
   - `CancelToken` tied to the view-model lifecycle.
3. **Result type** for repositories (sealed `Result<T>` = `Ok` / `Err(ApiFailure)`), as in the Flutter architecture guide.
4. **Logging:** `AppLogger` silent in `kReleaseMode`; a lint/test that forbids `print`/`debugPrint` outside the logger (P2-10).
5. **Time:** inject a `Clock`; parse server instants as UTC; display in `Africa/Tunis` via the `timezone` package; remove the hardcoded +01:00.
6. **Locale:** default `fr`; set up `flutter gen-l10n` with `app_fr.arb` as the template; migrate the existing 101-key map into ARB. From here on, **every touched string goes through ARB.**
7. **Mock cut-off:** no production-reachable import of `lib/mock_data`. Each mock-backed API either gets a real repository (later phase) or returns `Err(FeatureUnavailable)`, which the screen renders with its existing empty/error state. Remove `ReservationProvider.useMock()`.
8. **Guard test:** a test that walks the import graph from `lib/main.dart` and fails if `mock_data/`, `demo/` or `*_static_data.dart` is reachable.

**Done when:** the release build fails without config; the APK contains no `.env`; the guard test passes; `flutter analyze` shows no new warnings; all existing tests stay green.

### Phase 1c — Honest states (no invented content on screen) · M
Per §4.1 decisions:
- Home feed: hide the network-stats, referral and OmniBand blocks; generic greeting « Bonjour » when no first name; hide the language sheet entry; fix the duplicate-feed search item.
- Clinic detail: hide every `ClinicPresentationCatalog.defaultClinic` section (type, specialties, availability chips, invented doctors, insurers, facilities, hours, 24/7, languages, badges, distance, demo photos). Show only server fields.
- Doctor directory/detail: hide filters and sections driven by placeholder fields (rating 0.0, languages, insurance, age group, gallery, opening hours).
- Ma Santé: the 3 hardcoded documents and the fixture "+" editor are removed; the section is re-bound to `MedicalDocumentsScreen` in Phase 5.
- Document viewer: dead share/download/print/open buttons hidden until Phase 5.
- Delete the ~21k unreachable patient LOC (P0 §b.1) in **one separate PR with no behaviour change**; git history keeps it.

### Phase 2 — Auth and account · M (needs Spring work)
- Phone OTP as the primary sign-in, flag aligned with the backend (`PhoneVerificationProductionConfigurationValidator`).
- Google sign-in: hidden unless the server flag is on **and** mobile config exists (needs a Spring check on every Google endpoint, AUTH-02).
- **Password recovery:** Spring has no endpoint. Design an OTP-based reset (rate-limited, single-use, audited), then wire the existing `ForgotPasswordScreen`. Run **omnicare-security-review before BUILD**.
- Devices / sessions / phone change: already wired; verify the contracts and translate the errors.
- Logout: deregister the FCM token and clear all in-memory PHI caches.
- Backend items to coordinate (not patient-app code): OTP hashed in Redis + atomic counter (AUTH-03), login rate limit (AUTH-04).

### Phase 3 — Medical data source of truth (DATA-01) · M · **blocked by decision #1**
- The patient's own medical data (allergies, conditions, blood type, height, weight) is read and written through MRS-backed `/api/v1/profile/medical-data` (LIFE_SAFETY + BODY_MEASUREMENTS), **never `/api/v1/passport/**`**. That endpoint already exists (P0 G4); `/passport/**` stays `denyAll` permanently.
- Stop sending `medicalInfo` on `PATCH /profile/passport` (C2). Ma Santé and the passport tab read and write through `/profile/medical-data`.
- Onboarding steps that collect medical fields: verify which tables they write today (prod report: `OnboardingService` → `PassportService` → `passport_*`). Redirect those fields to the MRS path.
- Family members: the account holder may read and write a family member's medical data (ADR-003 §11.3). The server resolves the subject from `familyMemberId` with an ownership check; the app never sends a raw `patientId`. Whether `/profile/medical-data` already supports a family subject is UNVERIFIED → check first.
- Wire `MedicalDataEditorScreen` (today no API) to that path. Family members get the same treatment via their subject.
- **Three-state lists** (« Non renseigné » / « Aucune connue » / list): needs MRS LIFE_SAFETY v2 with `none_known` per section. This is a shared contract: G-2 owns it, the consultation chat consumes it.
- **Treatments are read-only**, coming from prescriptions (MRS `MEDICATION_STATEMENT` already requires a prescription source). The patient-side "add medication" is hidden (decision #2).
- One-time migration `passport_*` → MRS, run as an **audited admin command** (never manual SQL), report-only dry run first, backup before. Then a feature flag blocks `/passport/**` writes. Purge later, after verification (P5-20).

### Phase 4 — « Dossier médical » real (FEAT-01, BE-05) · L
Bind the existing passport screen sections; delete the fixture from the production tree.
| Section | Source | Backend work |
|---|---|---|
| Identity | `/api/v1/profile` | none |
| Allergies, antécédents, blood type | Phase 3 path | none beyond Phase 3 |
| Traitements en cours | MRS `/medications` | **new Spring patient route** (MRS route exists, no Spring caller today) |
| Consultations passées (completed only, summary) | MRS `/consultation-history` | **new Spring patient route**, keyset-paginated |
| Ordonnances, certificats (finalized) + PDF | per consultation: `/patient/consultations/{cid}/artifacts` **exists** (P0 G6) | **new aggregate list** "all my artifacts" (Spring, keyset-paginated); PDF download **streamed to a temp file with a size cap** (today the whole PDF is held in memory, `patient_artifact_card.dart:75-85`) |
| Documents | Phase 5 | Phase 5 |

Rules: every new Spring route checks that the caller is the account holder of the subject (SELF or their FAMILY_MEMBER), with the same 404 for "not yours" and "not found" (no existence leak). MRS audits every read. Lists paginated with a hard max page size. FLAG_SECURE on these screens.
**Does not touch** consultation write paths or guards: it only reads finalized outputs.

### Phase 5 — Documents (MRS-02, IDOR-01) · M · **needs decision on the contract**
- **App:** `MedicalDocumentsScreen` is real and tested but orphaned (F6). Re-bind the existing Ma Santé documents section and the passport documents tab to it (an allowed binding, §4.1 Q7). Add cursor pagination (today only the first 50) and show the user-entered name instead of raw enums (C19).
- Fix the broken Spring↔MRS contract: Spring calls `GET …/documents`, `…/{id}/status`, `…/{id}/events`, which don't exist. Recommendation: implement **list** and **status** in MRS; **drop the SSE events** route and poll status with backoff while the upload is processing (simpler, fewer long-lived connections).
- View documents through MRS **view-sessions** (watermarked pages). Keep raw download blocked, as designed.
- Upload: 15 MB in every layer (Spring is 20 MB today), pdf/jpg/png, ≤100 pages, ClamAV. Stream the upload from file; never read the whole file into memory.
- Backend items: IDOR-01 (any clinician can create a document request on any patient) and the « Dr. TODO » placeholder shown to patients.

### Phase 6 — Notifications and push (FEAT-04) · M · **needs decision #4**
- Firebase per environment: Android `google-services.json`, iOS `GoogleService-Info.plist`, APNs key, `aps-environment` entitlement, `UIBackgroundModes: remote-notification`.
- A top-level `onBackgroundMessage` handler annotated `@pragma('vm:entry-point')` (required since Flutter 3.3, see FCM docs).
- Pre-create the 4 Android channels (`omnicare_low/medium/high/critical`); remove `emergency_channel` and `test_channel`.
- Request notification permission (Android 13+, iOS) at a sensible moment, using the existing UI.
- **Payload policy:** data contains only `type`, `referenceId`, `notificationId`. No names, no clinical words. The app fetches the content via the API after tap. Backend `FcmDispatcher` currently copies **all** payload keys into FCM data: change it to an allow-list.
- Tap routing: extend `notification_navigation_resolver.dart` to every patient notification type that has an existing screen (P0 §e: 13 unrouted); unknown type or no screen → inbox. Depends on 1a-5 (semantic type in FCM data).
- Reminder payloads are empty today, so the placeholders print literally (`AppointmentReminderWorker.java:47,80`). Dates in templates must be Africa/Tunis, not `Instant.toString()`.
- Token lifecycle: register on login and refresh, delete on logout. Surface init failure (no silent swallow) to crash reporting.
- Backend coordination: notification times in Africa/Tunis (BE-03).

### Phase 7 — Appointments clean-up (PAT-06) · S
- Use one cancel endpoint (versioned `POST …/cancel`).
- Send money as a decimal **string**, never a double.
- Idempotency keys from the Phase 1 helper.
- Remove the legacy « Mes demandes » path if Phase 0 shows it is dead.
- French error mapping; Tunis time display.

### Phase 8 — Privacy controls (non-consultation) · S–M
- Sharing policy screen and per-consultation LOCKED/SHAREABLE: already real; verify, translate, test.
- **« Qui a consulté mon dossier »:** needs the patient access-log endpoint from the MRS audit hardening (MRS-03). If no screen exists → stop and report.
- Not ours: approve/revoke during an active consultation (G-1).

### Phase 9 — Ma Santé (FEAT-03) · M · **only if decision #3 keeps it in V1**
- A read-only Spring aggregate `GET /api/v1/masante` built from the Phase 4 reads (one call, no N+1 from the app).
- Bind the existing tab.
- Hardcoded marketing stats (`patient_home_feed.dart:801-805`): bind them or remove them.

### Phase 10 — Urgent care, patient side · **only if decision #3 keeps it in V1**
- Urgent cabinet: replace the synthetic activation gate with a server-driven flag plus a kill switch (MOB-07). This depends on the backend production mode (FEAT-02), which is not patient-app work.
- Urgent home (PAT-08): a full feature, not wiring. Out of this roadmap unless decided otherwise.
- **If out of V1:** hide both entry points (allowed by §1.3).

### Phase 11 — Release hardening · M
- **French:** remaining strings to ARB, `fr` default, `ar`/`en` secondary.
- **Dead code:** delete ~13.9k LOC of unreferenced legacy screens; keep `lib/demo` and `main_*.dart` out of the release build.
- **Android:** `allowBackup=false`, FLAG_SECURE on medical screens, release keystore (MOB-01) via CI secrets, `--obfuscate --split-debug-info`.
- **Crash reporting:** D-13 vendor, no PHI in breadcrumbs.
- **iOS:** build and signing.
- **Bundle IDs:** align them (decision #5).
- **Dependencies:** replace discontinued `js`, upgrade outdated packages, `flutter analyze` with 0 warnings.
- **Security:** MASVS L1 self-check across STORAGE, NETWORK, PLATFORM, PRIVACY and CODE.
- **Store:** listing, privacy policy URL.

### Phase 12 — Verification · M
- `integration_test` end to end against **staging** with a synthetic patient: login → profile → medical data → book → (a doctor completes a consultation elsewhere) → patient sees the ordonnance PDF → uploads a document → receives a push → opens the right screen → logout clears PHI.
- **omnicare-prod-gate** with evidence.

### Order and dependencies
```
P0 ✔ ─► P1a (fixes) ─► P1b (foundation) ─► P1c (honest states) ─┬─► P2
                                                                 ├─► P3 ─► P4 ─► P9
                                                                 ├─► P5 ─► (P4 documents section)
                                                                 ├─► P6  (needs decision #4; uses 1a-5)
                                                                 ├─► P7, P8
                                                                 └─► P11 (continuous) ─► P12
```

---

## 4. Decisions needed before the blocked phases (batch of 5)

| # | Decision | Recommendation | Blocks |
|---|---|---|---|
| 1 | **D-04: source of truth for the patient's medical data** | MRS. Freeze `/passport/**` writes behind a flag, migrate with an audited admin command, purge after verification | P3, P4 |
| 2 | **Patient-entered medications** | Read-only in V1 (treatments come from prescriptions only). Hide "add medication" | P3 |
| 3 | **D-01 V1 scope for the patient app** | Ma Santé IN as read-only; urgent cabinet and urgent home OUT, entry points hidden until FEAT-02 is solved | P9, P10 |
| 4 | **Firebase ownership + push payload policy** | Company-owned Firebase project per environment; IDs-only payloads, no names | P6 |
| 5 | **Bundle ID alignment** (Android `com.omnilinks.omnicare_mobile` vs iOS `com.omnilinks.omnicareMobile`) | Align now, before the first store release. Cheap today, impossible after publishing | P11 |

Phases 0, 1a, 1b, 1c, 2, 7 and 8 can start without these decisions.

### 4.1 Architect decisions on the P0 open questions (applied; CTO can overrule)
| P0 Q | Decision | Why |
|---|---|---|
| 1 | Roadmap committed at `OmniCare-App/docs/roadmap/G2_Patient_Flutter_Roadmap.md` | Claude Code reads the repo, not claude.ai |
| 2 | G-2 gate = §8 (now machine-checkable) | — |
| 3 | Urgent cabinet: CTO decision #3. Phase 1a still fixes its parsing (cheap, prevents crashes on enable) | Backend prod mode is not patient-app work |
| 4 | Urgent HOME: out of G-2. The review screen keeps routing to « indisponible » | Full feature (GPS, QR, matching), not wiring |
| 5 | Home feed: hide stats, referral, OmniBand; generic greeting | Invented numbers shown to patients are false claims. Hiding is allowed by §1.3 |
| 6 | Clinic/doctor catalogs: hide every STATIC field now; backend fields → Parking lot | Invented doctors, hours and insurers for real clinics mislead patients |
| 7 | Re-binding the existing Ma Santé documents section to `MedicalDocumentsScreen` is **allowed** (binding, not redesign) | §1.3 |
| 8 | Push alias: fix in the **backend** (semantic `type` + separate `templateType`) | One source of truth; the app must not know the alias table |
| 9 | Family medical data: allowed for the account holder via a subject-scoped server route, never a raw `patientId` | ADR-003 §11.3 |
| 10 | V1 = French only, `fr` default; ARB keeps `ar`/`en` slots for later; language sheet hidden | Invariant "UI 100% French" |
| 11 | Keep forcing out non-patient/non-doctor roles, but with a French explanation instead of a silent logout | Out of current focus (baseline §1) |
| 12 | Delete unreachable code in Phase 1c, one separate PR | ~21k LOC keep `lib/mock_data` alive; git history keeps it |
| 13 | Server is authoritative for phone OTP; the release app always offers phone OTP | Prod validator already forces it on |

---

## 5. Engineering standards (paste into every Claude Code prompt)

```
ENGINEERING STANDARDS — OmniCare patient app (G-2)
Architecture (Flutter official guide: docs.flutter.dev/app-architecture/guide)
- Layers: View (widget) → ViewModel (ChangeNotifier, via Provider) → Repository → Service (HTTP).
- Widgets never call the HTTP client. ViewModels never parse JSON. Repositories are the single
  source of truth and map DTO → immutable domain model.
- Errors are values: repositories return Result<T> (Ok/Err(ApiFailure)); no exceptions across layers.
- Keep Provider + Navigator 1 (as-built stack for V1). Do NOT add Riverpod, go_router, Bloc, or any
  new state/navigation library. Do NOT change layouts, styles or navigation structure.
- Dependencies injected through constructors, wired in main.dart. No service locators, no globals.

Clean code (Effective Dart)
- Small single-purpose classes and functions; names that say what they do.
- No dead code, no commented-out code, no TODO without a ticket id.
- No `dynamic` in domain models; no `!` on server data — validate and map to a failure instead.
- Exhaustive switch on sealed classes/enums, with an explicit `unknown` fallback for server enums.
- No magic numbers or strings: named constants.

Complexity and memory
- Every list endpoint is paginated (page/size or cursor) with a hard max page size. Never fetch "all".
- Lists render with ListView.builder / slivers (lazy). Never ListView(children: list.map(...)).
- No O(n²): build a Map<id, T> once instead of nested lookups. State the complexity of any loop
  over server data in the report.
- Files and PDFs are streamed to a temp file (download/upload by path). Never hold a whole file as
  Uint8List in state. Delete temp medical files when the viewer closes.
- Decode large JSON off the UI isolate (Isolate.run/compute) only when profiling shows jank.
- Dispose every controller, stream subscription and timer. Cancel in-flight requests on dispose.
- Debounce search input (300 ms) with a minimum length.
- In-memory caches are bounded and cleared on logout and on subject switch (PHI).
- Images: request a sized variant or use cacheWidth/cacheHeight.

Network
- One HTTP client. Timeouts on every call.
- Idempotency-Key = UUID v4 on every POST/PUT/PATCH/DELETE; reuse it only to retry the same intent.
- Retry only on network errors/5xx, only for idempotent-keyed requests, max 3, backoff with jitter.
- Never display server `message`/`detail` text. Map `code` → French ARB message.
- Money as decimal strings. Instants as UTC ISO-8601; display in Africa/Tunis via an injected Clock.

Security and privacy (OWASP MASVS v2)
- Tokens only in flutter_secure_storage.
- No health data or names in logs, analytics, crash breadcrumbs, push payloads, or URLs.
- FLAG_SECURE on screens that show medical data. No secrets in assets.
- Patient can only reach their own subject or their family members; the backend enforces it, and the
  app never sends an mrsPatientId.

i18n
- Every user-visible string goes through ARB (app_fr.arb is the template). No new hardcoded strings.
  No technical jargon in French copy (no "MRS", "version", "UUID", "canonique").

Backend changes (only when the phase requires them)
- Spring: constructor injection; records for DTOs; Bean Validation; keep the existing error
  envelope {code,message,fieldErrors} (do not change the global error format in this goal);
  @Transactional(readOnly = true) for reads; never call MRS inside a DB transaction (use the outbox
  for async work); ownership check on every id (same 404 for "not yours" and "not found");
  Pageable with a max size cap; no N+1 (projections or fetch joins); no new import of another
  module's repository. Tests: service unit + @WebMvcTest + Testcontainers for DB paths.
- MRS (Go): existing stdlib ServeMux patterns; context timeouts; pgx parameterized queries;
  wrapped errors; every medical read audited; append-only migrations; go vet + gofmt + go test.

Process
1. Plan first: read the listed files, write the plan (files, approach, tests, complexity). Then implement.
2. Implement in small steps. Run tests after each step.
3. Never edit the out-of-scope paths listed in the roadmap §1.2.
4. If a design question is not answered by the roadmap/ADRs, or a function has no existing screen:
   STOP and report. Do not decide.
5. Deliver: full report in OmniCare-App/docs/reports/G2/<id>.md, a chat summary of at most 1 page,
   and a final section "Path to deliver G-2".
```

---

## 6. Report format (every prompt)

File: `OmniCare-App/docs/reports/G2/<phase>-<topic>.md`
1. Goal card (verbatim) + deliverable status
2. What changed (files, with one line each) / what was inspected (read-only prompts)
3. Evidence: commands run and their output summary (`flutter analyze`, `flutter test`, backend tests)
4. Contract table for every endpoint touched (method, path, request, response, error codes)
5. Complexity and memory notes (lists, files, caches)
6. Risks, open questions, things NOT done and why
7. **Path to deliver G-2**: next 3 steps

---

## 7. Prompt #1 — Phase 0 inventory (read-only)

```
Repo: OmniCare-App (read) · OmniCare-BackEnd (read) · omnicare-mrs (read)
Branch: none — READ-ONLY. Do not modify, create or commit any source file.
Only file you may write: OmniCare-App/docs/reports/G2/G2-P0-inventory.md

GOAL G-2: Connect the patient Flutter app to the real backend without changing the current UI, with a report at every step.
Deliverables:
  1. A full, detailed roadmap for the patient app, consultation excluded
  2. The patient Flutter app connected to the backend (no UI redesign)
  3. A report for every step (saved in the repo)
  4. Claude Code prompts that enforce design patterns, clean code, bounded complexity/memory, and official docs
Done when: every patient screen reachable from production main.dart shows real data or an honest
"indisponible" state (no fixture, no mock), the release build passes the G-2 gate, and every step has a report.

Task: produce a factual inventory of the patient app's data wiring. This is the input for every later phase.

1. Plan: list the folders you will read and the method (how you trace reachability from lib/main.dart).
   Write the plan, then proceed.

2. Inventory (patient side only; ignore lib/features/doctor/**):
   a) Screen table — one row per screen reachable from lib/main.dart:
      screen file · route · view model/provider · repository/API class · HTTP method+path ·
      Spring controller+method that serves it (or "MISSING") · data source = REAL | MOCK | FIXTURE |
      STATIC | DEAD · loading/empty/error states present? (y/n) · tests (file names)
   b) Unreachable code: screens/classes not reachable from lib/main.dart (with LOC), lib/demo,
      main_*.dart, lib/mock_data — and every production-reachable import of them.
   c) Contract check for every REAL endpoint: compare the Dart DTO with the Spring DTO
      (field names, types, enums, nullability, money/decimal, dates/timezones). List mismatches.
   d) Cross-cutting counts with file:line: hardcoded user-visible strings (English vs French),
      DateTime.now() call sites, print/debugPrint, places that build an Idempotency-Key and its length,
      places that hold file bytes in memory, ListView(children: …) over server data, nested loops
      over server lists (O(n²) candidates).
   e) Push/notifications: every notification type the backend can emit to a PATIENT
      (NotificationType + templates) vs the types the app routes on tap.
   f) Error handling: which error envelope(s) the app parses; where server `message` text reaches the UI.
   g) Backend gaps: patient-side endpoints the screens need that do not exist
      (e.g. medications, consultation history, finalized artifacts for the patient, documents list/status).

3. Proposed wiring order: confirm or challenge roadmap phases 1–8 based on what you found.
   Mark any screen where a needed function has NO existing UI (we will not invent UI).

Rules:
- Read-only. Mark anything you could not verify as UNVERIFIED with the reason.
- Never print secrets, tokens, .env values or real patient data in the report (mask them).
- Every claim cites file:line.
- If something is ambiguous, list it under "Open questions". Do not decide.

Done when: G2-P0-inventory.md exists with sections a–g + wiring order + open questions,
a chat summary of at most 1 page, and a final section "Path to deliver G-2".
Do not change: any source, config, test or build file in any repo.
```

**What the CTO checks after Prompt #1:** `git status` is clean except the report file; the screen table covers every bottom-tab and home entry; every MOCK/FIXTURE row has a file:line; the backend gaps list matches §3 (or explains why not). Then paste the 1-page summary back here. I map it onto the phases and write the Phase 1 prompt.

---

## 8. G-2 gate (before calling the patient app production-ready)
Machine checks (CI or a script in `tool/g2_gate.sh`):
- `flutter analyze` → 0 warnings; `flutter test` → green; `flutter build apk --release` **fails** without `--dart-define-from-file`.
- Import-graph scan from `lib/main.dart` (the P0 script): 0 reachable imports of `lib/mock_data/**`, `lib/demo/**`, `*_fixture.dart`, `*_mock_data.dart`, `*_static_data.dart`.
- Re-run of the P0 screen scan: 0 navigable rows with source STATIC/FIXTURE/MOCK/DEAD (honest « indisponible » screens are allowed).
- `unzip -l app-release.apk | grep flutter_assets/.env` → empty.
- grep: 0 `print(`/`debugPrint(` outside the logger; 0 widgets rendering server `message`/`detail`.

Manual checks:
- No production-reachable mock/fixture/demo code (guard test green).
- Every screen: real data or an honest « indisponible » state; French copy, no jargon.
- Release build: release keystore, obfuscation, no `.env`, config from defines, allowBackup off, FLAG_SECURE on medical screens.
- Push works on Android and iOS, in background and terminated states, tap opens the right screen, no PHI in payloads.
- `flutter analyze` 0 warnings; `flutter test` green; integration test against staging green.
- omnicare-security-review passed for P2 (recovery), P3/P4 (medical data), P5 (documents), P6 (push).
- WS-0 items affecting the app closed: SEC-02 key rotated, MOB-01 keystore.

---

## 9. Official sources
- Flutter app architecture guide (MVVM, repositories, services): https://docs.flutter.dev/app-architecture/guide
- Flutter architecture recommendations: https://docs.flutter.dev/app-architecture/recommendations
- Flutter performance best practices: https://docs.flutter.dev/perf/best-practices
- Flutter internationalization (gen-l10n, ARB): https://docs.flutter.dev/ui/internationalization
- Firebase Cloud Messaging, receive messages in Flutter (background handler, permissions): https://firebase.google.com/docs/cloud-messaging/flutter/receive
- OWASP MASVS v2: https://mas.owasp.org/MASVS/
- Spring Framework error responses (RFC 9457 ProblemDetail): https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html
- Effective Dart: https://dart.dev/effective-dart (not re-checked on 2026-11-10)
- Spring Boot reference: https://docs.spring.io/spring-boot/ (not re-checked on 2026-11-10)

---

## 10. Changelog
- **v1.2 (2026-11-10 23:00):** added the §0.1 status board (deliverables, phases, what we did, next, pending decisions); removed source-control procedure from the roadmap at the CTO's request.
- **v1.1 (2026-11-10 17:30):** after the P0 inventory. Added §2.1 verified facts, Phase 1a (live fixes) and 1c (honest states), worktree rule, 5 error shapes, Phase 3 uses the existing `/profile/medical-data`, documents re-binding, backend push alias fix, §4.1 architect decisions, machine-checkable gate.
- v1.0 (2026-11-10 16:41): initial roadmap.
