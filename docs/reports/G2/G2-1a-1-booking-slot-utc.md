# G-2 · 1a-1 — Booking slot sent 1 h late (C1)
_Date: 2026-11-10 · Branch: `feature/g2-flutter-hardening` · Roadmap v1.2 §3 Phase 1a item 1 · Inventory finding F1 / contract row C1_

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

| # | Deliverable | Status after 1a-1 |
|---|---|---|
| 1 | Roadmap | ✅ done (v1.2, committed at `docs/roadmap/G2_Patient_Flutter_Roadmap.md`) |
| 2 | Patient app wired | 🔨 1 of 5 Phase 1a fixes delivered (C1) |
| 3 | Report per step | 🔨 2 reports (P0, this one) |
| 4 | Prompts | ✅ done |

**Result:** the booking request now POSTs exactly the server slot instants. The slot picker displays the same times as before. Proven by a contract test that goes through the real parser, mapper, controller, repository, API and HTTP client.

## 2. Root cause and what changed

### 2.1 Root cause (verified)
`groupAvailabilitySlots` stored `toTunisWallClock(startUtc)` (UTC + 1 h, still flagged `isUtc`) in `DoctorAvailabilitySlot.start/end`. `PatientBookingController.prepareIntent` sent `slot.start.toUtc()` (a no-op on a UTC-flagged value) as `requestedSlot.start`. So a slot the server published as `08:00Z` (09:00 Tunis) was POSTed as `09:00Z` (10:00 Tunis). Existing tests hand-built slots with `start == startIso`, so they never exercised the mapper.

### 2.2 Step-1 classification of every UTC→+01:00 shift in patient code
| Call site | Use | Verdict |
|---|---|---|
| `doctor_directory_mapper.dart:107-108` (before) `toTunisWallClock(startUtc/endUtc)` stored as `slot.start/end` | SENT-TO-SERVER and identity | **Bug (C1)**, fixed |
| `patient_booking_controller.dart:245-246, 262-263` `slot.start.toUtc()` | SENT-TO-SERVER and intent identity | Consumed the bug; fixed by the model change (now `slot.start`) |
| `doctor_directory_mapper.dart:155` `toTunisWallClock(DateTime.now())` | DISPLAY ("Aujourd'hui / Demain") | OK, unchanged |
| `doctor_availability_sheet.dart:52,58` `toTunisWallClock(DateTime.now())` | DISPLAY (initial month, next available day) | OK, unchanged |
| `doctor_directory_controller.dart:352-363` `availabilityRangeForMonth` | SENT-TO-SERVER (`from`/`to` query) | **Correct**: Tunis month start converted back to UTC (−1 h). Unchanged |
| `doctor_directory_controller.dart:374` `tunisCalendarMonth` | DISPLAY (month key) | OK, unchanged |
| `booking_review_screen.dart:373-376` `schedulingWallClock` | DISPLAY (expects a real instant) | OK, unchanged; it now receives the real instant (see §6 R1) |
| `doctor_directory_controller.dart:306` deprecated `bookSlot` sends `slot.startIso` | SENT-TO-SERVER | Correct (verbatim server string). Unchanged |
| `doctor_availability_sheet.dart:411` selection by `startIso` | identity | Correct. Unchanged |
| `.toLocal()` in documents, security, request history, notifications, QR, urgent cabinet waiting screen, clinic models | DISPLAY in **device** zone, never sent | Not C1. Device-zone display belongs to Phase 1b (Clock + Africa/Tunis) |

No ambiguous caller was found, so nothing required a STOP.

**Out-of-scope callers (G-1, `lib/features/doctor/**`, not edited)** that use the same shared slot model:
| Call site | Use | Effect of this fix |
|---|---|---|
| `doctor_proposal_controller.dart:248-249, 347-348` sends `slot.startIso` | SENT | Unchanged (verbatim string) |
| `doctor_proposal_controller.dart:353-357` `_isOriginal` compares `slot.start` to the server's original instant | identity | Was comparing a shifted value to a real one; now compares instants as intended |
| `doctor_proposal_screen.dart:224, 400` `formatSchedulingDateTime(slot.start, …)` | DISPLAY (expects an instant) | Was showing +1 h; now shows the same time as the chip label |

### 2.3 Files changed
| File | Change |
|---|---|
| `lib/features/patient_doctor/data/doctor_detail_models.dart` | `DoctorAvailabilitySlot` now holds only the server instants (`start`/`end` in UTC, `startIso`/`endIso` verbatim). It is built only through `DoctorAvailabilitySlot.fromServer`, which parses `start` from `startIso`, so the two can never diverge. It rejects unparseable or offset-less instants with `DoctorContractException`. `time`, `timeOfDay` and the new `tunisDate` are getters derived from the Tunis wall clock at display time. `toTunisWallClock` moved here (next to `doctorSchedulingTimezone`) and is documented as display only. Period boundaries are named constants. |
| `lib/features/patient_doctor/data/doctor_directory_mapper.dart` | `groupAvailabilitySlots` builds each slot with `fromServer` and groups it by `slot.tunisDate` in a single pass. `toTunisWallClock`, `_formatTime` and `_periodFor` were removed (moved into the model). |
| `lib/features/scheduled_care/application/patient_booking_controller.dart` | `RequestedSlot` and the semantic-intent check use `slot.start/end` directly (no shift, no no-op `toUtc()`). |
| `lib/features/patient_doctor/presentation/doctor_availability_sheet.dart` | Removed an import made unused by the move. |
| `test/booking_slot_utc_contract_test.dart` (new, 10 tests) | C1 contract test, display test, Tunis day boundaries, instant validation. |
| `test/scheduled_care_foundation_test.dart` | `_slot` / `_secondSlot` are now produced by the real `groupAvailabilitySlots` from recorded server instants, instead of being hand-built. |
| `test/doctor_directory_contract_test.dart` | `_day` builds slots from server instants via `fromServer`. `_slotUtc` and the "today" dates are now device-timezone independent. |
| `test/doctor_detail_availability_test.dart` | `_slotAt` and the "today" date are device-timezone independent. |

No UI layout, style, navigation or string change. No pubspec change. No backend change. Nothing under `lib/features/doctor/**` was edited.

## 3. Evidence

| Check | Before | After |
|---|---|---|
| `flutter analyze` | 388 issues (31 warnings/errors, all pre-existing) | 388 issues. Set difference against baseline: **0 new, 0 removed** |
| `flutter test` (full) | 1,709 passed, 7 skipped | **1,719 passed, 7 skipped, 0 failed** (+10 new) |
| `dart format --set-exit-if-changed` on touched files | — | exit 0 |
| Touched test files with `TZ=Africa/Tunis` / `UTC` / `America/Los_Angeles` | Baseline: **7 failures under `TZ=UTC`** (fixtures used device-local time) | 154/154 pass in all three zones |
| New contract file with `TZ=UTC` / `Pacific/Kiritimati` / `America/Los_Angeles` | — | 10/10 in each |
| **Mutation check:** reintroduced the shift in `prepareIntent`, ran the new file, then restored | — | 2 failures, as expected: POSTed `09:00Z` vs server `08:00Z`; review screen `· 10:00` vs chip `09:00` |

Flaky test (not caused by this change): one full run reported a failure in `test/doctor_home_presence_test.dart` ("permission revocation stops the bounded foreground cycle", expected `permissionRequired`, got `updated`). That file imports no code touched here. It passed 5 times in a row on its own, and the next full run was fully green. It looks timing-dependent under full-suite load; I'm recording it here for G-1.

### New tests (`test/booking_slot_utc_contract_test.dart`)
1. **POSTed start/end equal the server slot instants.** Recorded `GET /appointments/availability/slots` JSON → `AvailabilitySlotsDto.fromJson` → `groupAvailabilitySlots` → `PatientBookingController.prepareIntent/submit` → `ScheduledCareRepository` → `ScheduledCareApi` → `AppHttpClient` (Dio adapter records the wire body). It asserts that `requestedSlot.start/end` equal `2026-11-12T08:00:00Z` / `08:30:00Z` and end with `Z`, and that the controller accepts the server echo (status `succeeded`).
2. The mapper keeps the server instants (`isUtc`) and the verbatim `startIso`/`endIso`.
3. Display unchanged: `08:00Z` → `09:00 · Matin`, `13:30Z` → `14:30 · Après-midi`, day `2026-11-12`.
4. The review screen line shows the same time as the chosen chip (`jeudi 12 novembre 2026 · 09:00`).
5–8. Boundaries: `22:59Z` → 12 Nov 23:59 (Soir) · `23:00Z` → 13 Nov 00:00 · `23:30Z` → 13 Nov 00:30 · `23:30Z` and next-day `08:00Z` share one Tunis day. In each case `slot.start` stays the server instant.
9. An offset-less instant is rejected (`DoctorContractException`).
10. An explicit `+01:00` offset is normalised to the same UTC instant.

## 4. Contract table

| Method | Path | Request | Response | Error codes | Change |
|---|---|---|---|---|---|
| GET | `/appointments/availability/slots` | query `doctorId`, `practiceLocationId`, `from`, `to` (UTC ISO-8601) | `{doctorId, practiceLocationId, timezone, generatedAt, slots:[{start, end, durationMinutes?}]}`, instants as `Instant` (`…Z`) | unchanged | Parsing only: an offset-less instant is now a contract failure (Java `Instant` always serialises with `Z`) |
| POST | `/doctor-booking-requests` (`PatientBookingRequestController.java:50`) | `{requestId, doctorId, practiceLocationId, subject, requestedSlot:{start, end}}`. Backend type `RequestedSlotRequest(@NotNull Instant start, @NotNull Instant end)`, `start < end`, revalidated against the slot grid | `PatientDoctorBookingRequestResponse` with `originalRequestedSlot` | `SLOT_NO_LONGER_AVAILABLE`, `VALIDATION_FAILED`, `SUBJECT_NOT_AVAILABLE`, `BOOKING_CONTEXT_NOT_AVAILABLE`, `IDEMPOTENCY_CONFLICT` (unchanged) | **`requestedSlot.start/end` are now the server instants.** Wire form is `2026-11-12T08:00:00.000Z` (Dart `toIso8601String`) vs the server's `…08:00:00Z`: the same `Instant`, which Spring parses identically |

## 5. Complexity and memory
- `groupAvailabilitySlots`: one pass over n slots to group by Tunis day (O(n), map insert O(1)), then a sort within each day and a sort of the days: O(n log n) overall. The sorts existed before. Server lists are bounded by the requested range (≤ 31 days, `availabilityRangeForMonth`).
- `time` / `timeOfDay` / `tunisDate` are now O(1) getters computed on read instead of stored strings. That means two fewer strings per slot in memory and a trivial date add per chip build.
- No new caches, files, streams or controllers.

## 6. Risks, open questions, things not done

**R1. The review and request screens now show a different time than before, and it's the correct one (CTO acknowledgement needed).** The slot picker (chips, day strip, « Prochaine disponibilité ») is unchanged. But the booking review screen showed **+1 h** before this fix (it formatted the already-shifted value), and the mutation check proves it (`· 10:00` for a `09:00` chip). After the fix it shows the chosen time. For **new** bookings, the pending, confirmed and request-history screens also show the right time, because the server now stores the right instant. This is the bug fix, not a redesign.

**R2. Production data created before this fix (UNVERIFIED, no DB access).** Every patient booking request made through this path was sent 1 h late. The server either booked the later grid slot, if it was free, or answered `SLOT_NO_LONGER_AVAILABLE`. Affected requests can't be identified from their shape, since a +1 h request looks like a valid one. **Open question for the CTO:** do production or staging have patient-created booking requests? If so, decide how to handle them (list by creation date, contact patients or doctors). This is not app work.

**R3. Doctor-side (G-1) behaviour changes without any doctor file being edited.** `DoctorAvailabilitySlot` is shared. `doctor_proposal_screen.dart:224,400` showed the proposed slot +1 h and now shows it correctly. `doctor_proposal_controller.dart:353-357` `_isOriginal` now really matches the original slot. Wire bodies are unchanged (they use `startIso`). `test/doctor_proposal_test.dart` passes. **Announce to the G-1 chat** (roadmap §1.4).

**R4. Stricter parsing.** An availability instant without a UTC offset now fails the whole availability load (the existing error/retry panel) instead of being silently read in the device zone. The backend serialises `Instant`, so this should never occur.

**Not done (by design):**
- No `timezone` package and no injected `Clock`: Phase 1b. `toTunisWallClock` still hardcodes +01:00, now documented as display only.
- `'Matin' / 'Après-midi' / 'Soir'` and the day labels are still hardcoded French, moved as-is and not new. They go to ARB in Phase 1b.
- Device-zone `.toLocal()` displays listed in §2.2: Phase 1b.
- `doctor_home_presence_test` flakiness: G-1 territory, recorded only.

## 7. Path to deliver G-2
1. **CTO:** review this report, acknowledge R1, answer R2, and announce R3 to G-1. Then commit 1a-1.
2. **Run 1a-2 (C3):** blood-type sentinels `'-'`/`'IDK'` → the backend's unknown/blank value, plus the missing French save error on `EditMedicalDataScreen`, with a contract test through the real serializer.
3. **Then 1a-3 → 1a-5** (urgent-cabinet tolerant parsing and query length, `NO_SHOW`, backend push semantic type), one prompt each, then Phase 1b (where `Clock` + `timezone` replace `toTunisWallClock`).
