# OmniCare — G-2 Patient Flutter: backend wiring roadmap
_Owner: CTO (Mechergui) · Architect: Claude · v1.22 · 2026-11-11 23:55 · Status: ACTIVE (live status in §0.1; CTO decisions in §4 pending; architect decisions in §4.1 applied)_
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

## 0.1 Status board (updated 2026-11-11 23:45)

**In one line:** Active sub-goal **G-2.1 « Dossier médical »** (§0.3). ADR-012 **Accepted**; D1–D5 decided as recommended; write-path security review PASS with mandatory requirements R1–R11. Next: B1+B2 (MRS life-safety v3 + patient section routes). Rest of G-2 (1b-4…12) unchanged below. CTO manual tests pending for 1a–1b and G2.1-S1.

### Deliverables
| # | Deliverable | Status | Evidence |
|---|---|---|---|
| 1 | Detailed roadmap (consultation excluded) | ✅ done | this file, v1.2 |
| 2 | Patient app connected to the backend, no UI redesign | 🔨 building: 1a, 1b-1…1b-3b, FT-1…FT-3 done in code; G-2.1 « Dossier médical » in progress (§0.3) | reports below |
| 3 | A report for every step | 🔨 building: 21 reports | P0, 1a-1, 1a-2, 1a-2b, 1a-3, 1a-4, 1a-6, dev-ws, 1b-1, 1b-2, 1b-2b, 1b-2c, 1b-3, 1b-3b, FT-1, FT-2, FT-3, G2.1-S1, G2.1-S2 (+ FT-3 plan, FT-2 contract) |
| 4 | Prompts enforcing design patterns, clean code, complexity/memory, official docs | ✅ done | §5 standards, §6 report format, §7 Prompt #1 |

### Phases
| Phase | Content | Status |
|---|---|---|
| P0 | Read-only inventory | ✅ done (2026-11-10) |
| 1a-1 | Booking slot sent +1 h (C1, live P0) | ✅ done (2026-11-10): 1,719 tests green (+10), analyze unchanged (388 pre-existing); bug re-injected → contract test caught it; TZ-independent (Tunis/UTC/LA) |
| 1a-2 | Blood-type sentinels + missing save error (C3) + stop silent loss of conditions/meds (C2) | ✅ done in code (2026-11-10): 1,745 tests (+26), analyze unchanged; awaiting CTO manual test |
| 1a-2b | « Je ne sais pas » never erases a stored blood type; hide the Ma Santé documents "+" demo editor | ✅ done in code (2026-11-11): 1,769 tests (+24, logic only); awaiting CTO manual test |
| 1a-3 | Urgent-cabinet tolerant parsing (C4–C6), unified « indisponible » errors (C9), search limit 120 (C8) | ✅ done in code (2026-11-11): 1,809 tests (+40); awaiting CTO manual test |
| 1a-6 | Onboarding saves each page on « Continuer » and resumes at the first unsaved page (found in CTO test) | ✅ done in code (2026-11-11): 1,828 tests (+23); awaiting CTO manual test |
| dev-ws | Local Chrome WebSocket 403 (cause: local `.env` pinned :4200); prod loopback check hardened ([::1], 127.x, *.localhost) | ✅ done in code (backend); CTO edits local `.env` |
| 1a-4 | `NO_SHOW` request status (C10); C11 parsed, no UI (design gap); onboarding saved-page notice | ✅ done in code (2026-11-11): 1,848 tests (+20); awaiting CTO manual test |
| 1a-5 | Push semantic type (F7) | ↪️ **moved to Phase 6**: push is not configured at all, so it can't be used or tested before Phase 6 |
| 1b-1 | French by default + translation files (ARB, gen-l10n); migrate existing keys and `pending_fr_strings` | ✅ done in code (2026-11-11): app fixed to French (`lib/l10n/app_fr.arb`, class `OmniLocalizations`), 40 used keys kept, drift test; 1,858 tests; awaiting CTO manual test |
| 1b-2 | One error parser (5 backend shapes) → French messages; remove the 9 server-text sinks | ✅ done in code (2026-11-11): 8/9 sinks fixed (sink 4 is in G-1's folder → handed to G-1); Result<T> in FamilyRepository; 1,891 tests; awaiting CTO manual test |
| 1b-2b | Backend: send field constraint codes (`fieldErrorCodes`) so fields get precise French messages | ✅ done in code (2026-11-11): 6 codes (REQUIRED, TOO_LONG, TOO_SHORT, INVALID_FORMAT, OUT_OF_RANGE, INVALID), additive; 16/16 error-package tests |
| 1b-2c | Move the remaining feature error mappers (requests, booking, directories, urgent cabinet, documents, auth) onto the parser; precise field messages; fix the "SMS" wording | ✅ done in code (2026-11-11): no patient feature parses error JSON any more; 1,914 tests; awaiting CTO manual test |
| 1b-3 | Mock cut-off + import-guard test (no mock/fixture/demo reachable from `main.dart`) | ✅ done in code (2026-11-11) except « Dossier médical » (stopped correctly: 5 of 7 sections have no honest unavailable state); 1,931 tests; guard proven |
| 1b-3b | « Dossier médical » interim unavailable block (CTO-approved temporary exception): header + identity card kept (real profile, real family members, G-1's share icon and « Afficher le QR »), one card « Votre dossier médical n'est pas encore disponible dans l'application. »; build-time switch `MEDICAL_RECORD_LIVE` off by default | ✅ done in code (2026-11-11 22:00): fixture unreachable from patient code (guard proven by re-adding the import); fixture file kept for G-1's doctor preview only; no pencil, no 180/78; awaiting CTO manual test |
| FT-1 | Backend (Spring): patient read routes for treatments, consultation history, finalized prescriptions/certificates (over existing MRS routes); confirm family subject on `/profile/medical-data` | ✅ done in code (2026-11-11): Spring `GET /api/v1/me/medical-record/{medications,consultations,artifacts,medical-data}?subject=SELF\|FAMILY:{id}`; 2 new read-only audited MRS routes (`consultation-summaries`, `official-artifacts`); 48 + 10 new tests; security review owed before FT-3 ships |
| FT-1-SR | Security review of FT-1 (architect) | ✅ PASS for FT-3 to proceed; 0 new P0; P1s: verify the Spring→MRS signature covers actor/purpose/subject headers; FLAG_SECURE + cache clearing ship with FT-3; `/profile/medical-data` transaction across MRS (existing) |
| FT-2 | Documents list/status (MRS-02 contract fix, MRS + Spring) — Phase 5 core pulled forward | ✅ done in code (2026-11-11): Spring `GET /api/v1/me/medical-record/documents` (+`/{id}/status`), returns `title`; MRS list/status reused (already added by G-1 `cd206f9`) + 4 patient-path DB tests; dead SSE `/events` chain removed (clients poll status); 15 MB already aligned Spring/MRS (app still 20 MB → FT-3b); signature covers actor/purpose/subject headers ✅ (FT-1-SR P1 closed). **STOP: no patient viewing path exists → decision #6** |
| FT-3 | App: wire the fixed « Dossier médical » UI to the FT-1 routes (blood type, allergies, conditions, measurements, treatments, history); switch stays OFF | ✅ done in code (2026-11-11 22:00): honest texts per status; per-card spinner / French error + « Réessayer »; first 20 only; family switch cancels + clears + ignores late answers; logout clears; FLAG_SECURE via Android channel (switch ON only); 1,946 tests green, analyze 388 (no new). Notes: specialty is free text (shown as entered); OmniCare ID row shows « Non renseigné » (→ hide in FT-3b); deleted fixture widget test; adapted G-1's `test/p5_06_patient_qr_test.dart` (told G-1). Awaiting CTO manual test |
| FT-3b | ~~Documents section + switch flip~~ | ↪️ **superseded by G-2.1** (§0.3: SB3, B5, A4) |
| FLIP | ~~Switch ON by default~~ | ✅ done differently: CTO asked for no switch; G2.1-S1 deleted `MEDICAL_RECORD_LIVE` and the temporary card (2026-11-11 23:30) |
| FT-2b | Patient views own document | ↪️ now G-2.1 B5 + SB3 (decision #6 = A; D3 confirms; G-1 review of MRS view rules) |
| FT-4 | Ordonnance/certificat PDF: streamed, size-capped download + opening a private file (`open_filex` vs native FileProvider: decision open) | ⏳ needed by G-2.1 A5 if D4 = show finalized documents in the expanded history card |
| 1b-4 | Build config per environment; `.env` out of the APK; release fails without config | ⏳ |
| 1b-5 | Logger silent in release; no `print`/`debugPrint` outside it | ⏳ |
| 1b-6 | Tunis time zone package + injected clock (replace hardcoded +01:00) | ⏳ |
| 1b-7 | Tidy-ups: request-detail must not fail on a malformed proposal; flaky `doctor_home_presence_test`; 2 scheduled-care tests flaky in full runs (seen in FT-3) | ⏳ |
| 1b-8 | Translation pass: English-heavy reachable patient screens into `app_fr.arb` (request detail, request errors, documents first); booking and urgent-cabinet texts into ARB; copy review: no developer wording (« CABINET », « synthétiques », « environnement ») | ⏳ |
| 1c | Honest states: hide invented home/clinic/doctor content; delete unreachable code | ⏳ |
| 2 | Auth and account (password recovery needs Spring + security review) | ⏳ |
| 3 | Medical data via `/profile/medical-data` (MRS) | ⏳ #1 decided (MRS); still blocked by #2 (medications read-only) |
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
5. Fixed 1a-1. Side effects accepted: the review/pending/confirmed screens now show the correct time (they showed +1 h); the doctor slot-proposal screen also shows correct times (announced to G-1).

### Next
1. Run 1a-2, then review its report.
2. Then 1a-3 → 1a-5, one prompt at a time, each reviewed before the next.
3. Then Phase 1b, then 1c.

### Waiting on the CTO (§4)
~~#1 MRS as source of truth~~ ✅ decided (MRS) · #2 medications read-only · #3 V1 scope (Ma Santé in, urgent out) · #4 Firebase ownership + push payload policy · #5 bundle IDs. None blocks Phase 1.

### New issues found
- **APP-C1 (P0):** patient booking slot sent +1 h — **fixed in 1a-1**; no real patients affected (§0.2 closed). Awaiting CTO manual UI test.
- `doctor_home_presence_test` flaked once in a full run (timing) → fix in Phase 1b.
- `flutter analyze` has 388 pre-existing issues; the gate (§8) requires 0 → burn-down in Phase 1b/11.
- Parking lot: clinic/doctor backend fields (G12, G13); schedule-proposal accept/reject UI (C11); forgot-password and account-deletion UI (need design).

## 0.3 G-2.1 « Dossier médical » — ACTIVE (paused 2026-11-11 23:45)

```
GOAL G-2.1: Make the « Dossier médical » section work 100% with the backend and MRS, with the current UI,
validation and error handling.
Deliverables:
  1. Every element of the current « Dossier médical » screen works with the backend and MRS
     (Résumé, Historique, Documents, the editor, the family selector, the QR code, sharing),
     for the patient and for each family member
  2. The current UI unchanged (no hidden, removed or redesigned element; no switch, no temporary card)
  3. Validation: wrong input is refused with a clear French message, in the app and on the server
  4. Error handling: every failure shows a French message and a way to retry, and nothing typed is lost
Done when: on a plain `flutter run -d chrome` with a new test account, the CTO can enter an allergy in
onboarding and see it in the record; view/add/edit/delete his data, then switch to a family member and do
the same for them only; see a French message for each wrong value; stop MRS and see an error with
« Réessayer » with nothing lost; hide a consultation; upload and open a document; show the QR code.
Every step has a report in OmniCare-App/docs/reports/G2/.
```

**Deliverable status:** 1 deciding (reads work; no write path exists) · 2 building (switch gone; pencil still hidden) · 3 deciding · 4 started (read side only).

**Binding rules:** ADR-012 v1.0 (`claude/OmniCare_ADR-012_Patient_Managed_Medical_Data.md`) — **Accepted by the CTO 2026-11-11 23:43** (with D1–D5 in its §8). Summary: MRS only (no legacy reads/writes, no migration, purge before launch); subject scope SELF|FAMILY; per-item authorType, patient edits/deletes only PATIENT items, blood type locked once set by a professional; three-state lists (untouched = unchanged, emptied = NONE_KNOWN); patient-declared medications (outside OmniCare) labelled « Déclaré par le patient », OmniCare prescriptions read-only; life-safety never hidden, the lock hides consultations only; server validation, configurable clinical ranges (REQUIRES MEDICAL VALIDATION), Idempotency-Key + per-section version (409), every write audited.

**CTO decisions recorded (2026-11-11 22:43–23:09):** edits scoped to the selected person; patient can't delete professional items; patient can hide consultations; patient-declared meds = outside OmniCare only; emptied section = « Aucune connue »; onboarding allergies must land in MRS and show in the record; no switch; no legacy migration (new test patient); ADR written.

| Step | Repo | Content | Status |
|---|---|---|---|
| S1 | App | Delete `MEDICAL_RECORD_LIVE` + temporary card; FLAG_SECURE always on this screen | ✅ done in code (1,946 tests green, analyze 388); CTO manual steps §6 of `G2.1-S1-remove-switch.md` pending |
| S2 | all (read-only) | Parity table (28 rows), write paths, MRS gap vs ADR-012, editor mapping, validation inventory, QR cause, build plan | ✅ done (`G2.1-S2-dossier-medical-parity.md`) |
| B1 | MRS | ▶️ prompt issued with B2 (2026-11-11 23:55). LIFE_SAFETY v3 payload (blood type with author; allergies/conditions items with itemId, label, authorType, severity?; status + version per section); v1/v2 read as v3 (author: `source=CONSULTATION` → PROFESSIONAL; holder-written → PATIENT; else PROFESSIONAL); validation field codes; ranges from config + soft-warning shape | ⏳ after D5 + ADR-012 approval |
| B2 | MRS | Patient section routes (blood type, allergies, conditions, measurements) per subject; expected version → 409; Idempotency-Key; audit per section; rules 3–4; 404 for missing/not owned | ⏳ |
| B3 | MRS | `PATIENT_MEDICATION` add/edit/delete (name, dosageText, timesPerDay, duration, startedOn); merged medication read with `source`; medication list status (migration 000041 if a new singleton) | ⏳ |
| B4 | MRS + **G-1 review** | Consultation life-safety writes stamp PROFESSIONAL; v4 merge keeps PATIENT items; workspace stops hiding life-safety (rule 6, ADR-003 §7.2) | ⏳ needs G-1 |
| B5 | MRS | Patient view-session for own documents (watermarked, no raw download) | ⏳ D3 + G-1 |
| SB1 | Spring | `/api/v1/me/medical-record` write routes `?subject=` (sections, measurements, medications); same 404; Bean Validation + `fieldErrorCodes`; Idempotency-Key via `command_receipts`; expectedVersion → 409; audit; **synchronous MRS call outside any DB transaction**; security matchers | ⏳ after B1–B3 |
| SB2 | Spring | MRS only: remove SELF legacy fallback (`PatientMedicalRecordService:222`, `UserProfileService:106-133`); onboarding steps 2–4, `PATCH /profile/passport` and family passport → SB1 services (allergies, **all** conditions, medications at their step); no `passport_*` read/write; delete dead `PassportController` | ⏳ |
| SB3 | Spring | Documents under `/me/medical-record/documents`: subject-scoped upload (streamed, 15 MB), delete, view-session | ⏳ D3 |
| A1 | App | Repository writes `Result<T>`: Idempotency-Key, expectedVersion, 409 → reload + keep draft, `fieldErrorCodes` → French ARB | ⏳ |
| A2 | App | Pencil back; editor wired (every field + Allergies section per D2); no A+ default; refusal messages; PROFESSIONAL items + locked blood type read-only; « Déclaré par le patient »; IMC category computed (not hard-coded « Normal »); per-member scope | ⏳ |
| A3 | App | Onboarding, Ma Santé, family screen on the same write path; English onboarding messages → ARB; free-text medications | ⏳ |
| A4 | App | Documents tab: list, upload (« + »), open, delete, real count, per member | ⏳ |
| A5 | App | History: expand per D4; filters built from real data (remove fake doctors, « Annulée »); lock-toggle errors shown; family selector fixes (row height, `photoUrl`, select by id); sharing snackbars → ARB | ⏳ |
| A6 | App | Acceptance run of the full "Done when" on a new account; G-2.1 gate (security review + prod-gate) | ⏳ |

Order: B1 → B2 → B3 → SB1 → SB2 → A1 → A2 → A3; in parallel B4 (G-1), B5 + SB3 → A4; A5; then A6. Security review (omnicare-security-review) of the write path **before** B2/SB1 are built.

**Decisions (CTO approved "D1–D5 as recommended", 2026-11-11 23:43):**
| # | Decision | Recommendation |
|---|---|---|
| D1 | QR exists only during an active consultation (G-1 freeze, `MedicalSharingService.java:188-190`) | Keep it; run the QR acceptance step during a consultation |
| D2 | Editor has no Allergies field; « Allergie Pénicilline » is in the conditions presets | Add an « Allergies » section reusing the existing chip widget; move the chip; both preset lists REQUIRES MEDICAL VALIDATION (small, approved UI addition) |
| D3 | Patients can't open their documents | Yes (already decision #6 = A): watermarked view-session for the owner, raw download blocked |
| D4 | Expanded history card has no content | Reason, specialty, doctor, date + that consultation's finalized documents (ordonnance, certificat); no diagnosis/notes until a medical decision |
| D5 | Patient writes are async (outbox, 202) | Synchronous MRS call for patient edits (outside DB transactions, Idempotency-Key); outbox stays for system jobs |

**Security review of the patient write path (architect, 2026-11-11 23:55): PASS for BUILD with mandatory requirements**
- R1 `authorType`/author id set by the server from the authenticated actor, never accepted from a request body (mass-assignment test).
- R2 Subject resolved by Spring (session + familyMemberId); MRS re-checks the holder relation; same 404 for missing / not owned / deleted or graduated member.
- R3 Item operations: the item must belong to that subject's record; a PROFESSIONAL item → `ITEM_LOCKED` (patient already sees it, so no existence leak); blood type set by a professional → `BLOOD_TYPE_LOCKED`.
- R4 Idempotency-Key scoped to (actor, route, subject); same key + different body → rejected; replay returns the first result.
- R5 Per-section optimistic version; 409 `RECORD_VERSION_CONFLICT` returns code + current version only, never values.
- R6 Validation never echoes values; free text trimmed, NFC-normalised, control characters rejected, length/count limits, no duplicates; stored and rendered as text only (G-1: Angular must never bind patient text with innerHTML/bypassSecurityTrust).
- R7 Audit ATTEMPTED/COMPLETED/FAILED per section write: actor, role, subject, section, purpose (SELF_SERVICE | FAMILY_MANAGEMENT — today family writes wrongly send SELF_SERVICE), authorType; no values.
- R8 Synchronous Spring→MRS call outside any DB transaction; timeouts; retry only with the same Idempotency-Key; MRS down → 503 `MRS_UNAVAILABLE`; signed headers (already verified FT-2).
- R9 No health values in logs, URLs, analytics, push; a log-capture test on the new routes.
- R10 Spring security matchers PATIENT-only on the new write routes; confirm the CSRF posture of cookie sessions on Flutter web for state-changing routes (report, P1 if missing).
- R11 Rate limit per session on write routes (P2).

**Findings parked into the plan:** editor unknown blood type silently became A+ (A2); IMC pill hard-coded « Normal » = health claim (A2); onboarding conditions/meds never reach MRS (SB2); patient PUT can overwrite a doctor's blood type (B2); « Ajouter un document » closes without saving (A4); OmniCare ID row « Non renseigné » (CTO decision still open: hide the row recommended).

**To G-1 (hand-offs):** (1) **P0 release blocker:** doctor workspace hides life-safety data by default (`mrs/workspace/repository.go:118-130`, `service.go:187-226`), contradicting ADR-003 §7.2 (Accepted); (2) B4 author stamping + v4 merge review; (3) B5 MRS view rules for patient owners; (4) sharing-sheet 404 says « passeport familial » for SELF; server text can reach the UI (`medical_sharing_api.dart:157-161`); (5) earlier: IDOR-01, `eventStreamTimeout`, QR test adapted.

## 0.2 Bookings made before fix 1a-1 — CLOSED
CTO confirmed (2026-11-10 23:44): every environment holds **test accounts only, no real patients**. Pre-fix bookings are test data; nothing to correct.
Rule kept for the future: if real patients ever exist, corrections go through the audited reschedule/cancel flows, never a manual database edit.

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
- Upload: 15 MB in every layer (Spring and MRS already 15 MB per FT-2; the app is 20 MB → fix in FT-3b), pdf/jpg/png, ≤100 pages, ClamAV. Stream the upload from file; never read the whole file into memory.
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
- Use one cancel endpoint (versioned `POST …/cancel`). **Precondition (from G-1, 2026-11-11):** the versioned POST only accepts appointments created through a booking request; external-patient appointments, older bookings and follow-ups can only be cancelled through the legacy `PATCH`. Order: (1) extend the POST to every appointment type (backend), (2) move the patient app's cancel to it, (3) only then retire the PATCH. Until then the PATCH stays.
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
- **Manual end-to-end run by the CTO** against staging with a test patient, following a checklist written by the architect: login → profile → medical data → book → (a doctor completes a consultation elsewhere) → patient sees the ordonnance PDF → uploads a document → receives a push → opens the right screen → logout clears data.
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

## 4. Decisions needed before the blocked phases

| # | Decision | Recommendation | Blocks |
|---|---|---|---|
| 1 | **D-04: source of truth for the patient's medical data** — ✅ **DECIDED by CTO 2026-11-11: MRS** (ADR-004 amendment to write) | MRS. Freeze `/passport/**` writes behind a flag, migrate with an audited admin command, purge after verification | P3, P4 (unblocked) |
| 2 | **Patient-entered medications** | Read-only in V1 (treatments come from prescriptions only). Hide "add medication" | P3 |
| 3 | **D-01 V1 scope for the patient app** | Ma Santé IN as read-only; urgent cabinet and urgent home OUT, entry points hidden until FEAT-02 is solved | P9, P10 |
| 4 | **Firebase ownership + push payload policy** | Company-owned Firebase project per environment; IDs-only payloads, no names | P6 |
| 5 | **Bundle ID alignment** (Android `com.omnilinks.omnicare_mobile` vs iOS `com.omnilinks.omnicareMobile`) | Align now, before the first store release. Cheap today, impossible after publishing | P11 |
| 6 | **Patient viewing of own documents** — ✅ **DECIDED by CTO 2026-11-11 18:00: A (patients can open their own documents)** | A, sequenced: FT-3b ships list + status with « Aperçu indisponible » on tap; FT-2b adds watermarked viewing (G-1 approves/owns the `view_authority.go` change) and flips the tap to the viewer | FT-3b (viewing only) |

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

Testing split (CTO rule, 2026-11-10)
- Automated tests cover LOGIC only: mappers, parsers, controllers/view models, repositories,
  request/response contracts. Do NOT write widget, golden or integration tests, do NOT run the app,
  and do NOT check screens. UI is tested manually by the CTO.
- Every report ends with "Manual test steps for the CTO": numbered steps on a real device or
  emulator, the exact screen, what to tap, what must appear (French text), and what to send back.

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
7. **Manual test steps for the CTO** (screens, taps, expected French text, what to report back)
8. **Path to deliver G-2**: next 3 steps

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
- `flutter analyze` 0 warnings; `flutter test` green; CTO manual end-to-end checklist passed.
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
- **v1.22 (2026-11-11 23:55):** ADR-012 Accepted; D1–D5 decided as recommended; write-path security review PASS with R1–R11; B1+B2 prompt issued.
- **v1.21 (2026-11-11 23:45, PAUSE):** New sub-goal G-2.1 « Dossier médical » (§0.3) with ADR-012 (Proposed). G2.1-S1 done (switch + temporary card deleted; FT-3b/FLIP superseded). G2.1-S2 done (parity inspection). Build plan B1–B5 / SB1–SB3 / A1–A6 recorded; decisions D1–D5 pending; P0 to G-1: workspace hides life-safety data against ADR-003 §7.2. Phase 3 superseded on two points by ADR-012 (no migration; patient-declared medications).
- **v1.20 (2026-11-11 22:20):** 1b-3b + FT-3 done in code (1,946 tests green). Fake patient removed from release builds (awaiting CTO test). New FLIP row with gate: a blood-type edit (legacy `/profile/passport`) must show in the record (MRS) for self and family, else Phase 3a first (DATA-01 two sources of truth: also a clinical-safety issue, since doctors read MRS). OmniCare ID row → hide in FT-3b (no real ID exists). Parked: specialty is free text (a coded specialty is a doctor-profile change); iOS screenshot/app-switcher protection → Phase 11. To G-1: their QR test was adapted; shared cards changed only by optional additions.
- **v1.19 (2026-11-11 18:10):** Decision #6 = A (CTO). FT-3 stopped at plan: 1b-3b never ran, so FT-3 had no switch. Combined prompt: Part 1 1b-3b, Part 2 FT-3. Architect calls on the FT-3 blockers: conditions honest text as plain text in the existing body style (a chip reads like a diagnosis); per-card error text + default « Réessayer » TextButton; ordonnances out of the passport for V1 (they stay on the consultation screens); edit pencil hidden until Phase 3 (an unwired or partial save could turn « Non renseigné » into « Aucune connue », a safety risk); PDF hardening + file opener → FT-4. Parked: history « voir plus » (first 20 only; filters apply to the loaded page).
- **v1.18 (2026-11-11 17:55):** FT-2 done (report `G2-FT-2-documents-contract.md`). FT-1-SR P1 "signature coverage" closed with evidence (`MrsGatewayRequestSigner.java:208-231`, `serviceauth/protocol.go:35-47`, prod refuses unsigned). New decision #6 (patient document viewing), FT-2b added. IDOR-01 latent (route tree denied by `anyRequest().denyAll()`, `AuthWebSecurityConfig.java:286`) → P1, guard needed before any matcher opens it. Parked: legacy `GET /api/v1/documents` accepts limit 51–100 (retire after FT-3b); MRS audits list/status as `MRS_DECRYPT` (fine; note for audit reporting). To G-1: drop `eventStreamTimeout` from `MedicalSharingComposedIntegrationTest`; patient documents path now depends on G-1's `list.go`/`authorization.go` (4 DB tests guard it); IDOR-01 if document requests are theirs.
- **v1.17 (2026-11-11 17:40):** CTO chose option A (FT-2 + FT-3 + security review in parallel). Defaults applied: keep `MRS_UNAVAILABLE`; skip FT-1 command-line tests (checked through the app after FT-3). FT-1 security review: PASS for FT-3. FT-3b added (documents + switch flip).
- **v1.16 (2026-11-11 17:30):** FT-1 done. Parked: `/profile/medical-data` holds a DB transaction across the MRS call (P1); SELF medical-data still falls back to legacy plaintext columns until the Phase 3 migration; medications paged in Spring from the full MRS list (paged MRS route if lists grow); artifacts index `(mrs_patient_id, finalized_at DESC, id DESC)` if volume grows; download fails for claimed practice patients (authority-transfer phase). To G-1: dead `consultation-history` MRS route (unreachable scope, no audit); failing MRS artifacts test in G-1's uncommitted code; untracked `followup/` tests break Spring test compilation.
- **v1.15 (2026-11-11 17:15):** CTO clarified: 1b-3b is NOT cancelled. It is approved as a temporary exception to "UI unchanged" until the record is fully wired (FT-3 removes it). The release blocker for the fake patient lifts once 1b-3b lands.
- **v1.14 (2026-11-11 17:10):** CTO: the record UI is fixed (no redesign); 1b-3b cancelled; fast-track FT-1…FT-3 (Phases 3–5 read side pulled forward); fake patient accepted until FT-3 with a release blocker. Doctor view of the patient record (read-only, no family selector, no sharing, no PDF) handed to G-1. Assumption: decision #2 = treatments read-only (from prescriptions).
- **v1.13 (2026-11-11 17:00):** CTO decisions: fix the fake patient now regardless; decision #1 = MRS. Design canvas « OmniCare — Dossier médical indisponible » (2 artboards: now / Phase 4) awaiting CTO choice before 1b-3b runs.
- **v1.12 (2026-11-11 16:55):** 1b-3 done. Decision on « Dossier médical »: neither hide the tab (would hide G-1's QR/sharing) nor a partial fill; keep the header, replace all medical sections with one existing unavailable state (1b-3b). Per-section unavailable design (Figma) moves to Phase 4. To G-1: doctor screens still use mock consultations and the Sarah fixture.
- **v1.11 (2026-11-11 16:35):** 1b-2c done. Decision: Result<T> adopted when a repository is rewritten for wiring (Phases 3–5), not as a standalone refactor. Copy review of urgent-cabinet wording added to 1b-8. Parked: staff clinic workspace still reads server text (not patient scope).
- **v1.10 (2026-11-11 16:05):** 1b-2b done. Phase 7 cancel precondition (extend versioned POST before retiring PATCH). Parked: unify field-code names with G-1 (`INVALID` vs `INVALID_VALUE`); parameter-constraint failures return 500 instead of 400 (backend hardening).
- **v1.9 (2026-11-11 15:45):** 1b-2 done; 1b-2b (backend field codes) and 1b-2c (remaining mappers) added. Parked: patient consultation_detail_screen server text → Phase 4.
- **v1.8 (2026-11-11 02:00):** 1b-1 done; 1b-8 translation pass added. Decisions: 61 unused keys dropped (ar/en return as new ARB files later); the 7 skipped login tests are deleted with unreachable code in 1c; the language screen stays hidden.
- **v1.7 (2026-11-11 01:35):** 1a-4 done; 1a-5 moved to Phase 6; Phase 1b split into 1b-1…1b-7. Rule: no SQL shortcuts to create test states, even on test data. Proposal card design parked until D-01 (clinic flow in V1?).
- **v1.6 (2026-11-11 01:00):** 1a-3, 1a-6 (from CTO manual test) and dev-ws done; 1a-4 next. Decisions: saved onboarding pages are edited later from the profile (no backend onboarding-update path); keep pre-rule widget tests.
- **v1.5 (2026-11-11 00:05):** 1a-2 done; 1a-2b added (stored blood type protected; demo "+" editor hidden).
- **v1.4 (2026-11-10 23:50):** testing split: Claude Code tests logic only; the CTO tests UI manually from a step list in every report (§5, §6, §8, Phase 12).
- **v1.3 (2026-11-10 23:45):** 1a-1 done; §0.2 pre-fix bookings; 1a-2 scope adds C2 honesty.
- **v1.2 (2026-11-10 23:00):** added the §0.1 status board (deliverables, phases, what we did, next, pending decisions); removed source-control procedure from the roadmap at the CTO's request.
- **v1.1 (2026-11-10 17:30):** after the P0 inventory. Added §2.1 verified facts, Phase 1a (live fixes) and 1c (honest states), worktree rule, 5 error shapes, Phase 3 uses the existing `/profile/medical-data`, documents re-binding, backend push alias fix, §4.1 architect decisions, machine-checkable gate.
- v1.0 (2026-11-10 16:41): initial roadmap.
