# P4-UI-00 — Static UX Readiness Summary

**Review date:** 2026-10-10

**Verdict:** Strong reusable presentation assets; not ready for P4 production wiring or end-to-end static sign-off

## 1. Deliverables

| File | Purpose |
|---|---|
| `P4-UI-00_Screen_Inventory_and_Route_Map.md` | Actual Patient/Doctor routes, screen-by-screen findings, controller/data dependencies and test evidence |
| `P4-UI-00_Patient_Doctor_Gap_Assessment.md` | HOME/CABINET and Doctor gap reports, four contract errata, privacy projections and full state coverage |
| `P4-UI-00_Static_UX_Implementation_Plan.md` | KEEP/REUSE/REPAIR/REPLACE matrix, priorities, synthetic fixtures, tests, dependencies and exact next task |

## 2. Production-quality readiness assessment

The current Flutter urgent UX is **component-ready but journey-not-ready**.

Reusable strengths include the approved visual language, explicit HOME subject-selection screen, family-member UI, body map and pain scale, robust HOME destination chooser, editable review, synthetic matching presentation, mature Doctor/cabinet directory visuals, Doctor offer/wait/route cards, map fallback, reduced-motion handling and meaningful viewport/large-text tests.

The current route cannot be wired to P4 safely:

- HOME selection passes an arbitrary Doctor ID, not a live accepted hold.
- The HOME candidate fee is hidden until after selection and has no immutable currency/version model.
- The next screen creates a legacy consultation with free text and exact GPS.
- Timers fabricate commitment/travel/completion progress.
- CABINET is a scheduled slot/booking flow rather than a targeted urgent attempt.
- Doctor availability is local state and does not represent shared P4/P5 admission or fail-closed uncertainty.
- Doctor pre-commit cards include free-form triage and exact distance and omit the applicable fee.
- Patient and Doctor P4 routes enter QR/grant/medical-record/consultation behavior owned by P5.
- Cancellation, recovery, actual live choices, expiry conflicts, reconnect and post-handoff reactivation are incomplete.
- Urgent strings are not fully localized and RTL/accessibility certification is absent.

## 3. Contract errata recorded

1. Attempt mode is immutable; HOME-to-CABINET fallback is a new linked attempt in the same journey.
2. CABINET Patient target selection occurs before Doctor acceptance.
3. Canonical-subject equivalence across accounts is not journey-access authority.
4. HOME commitment requires explicit Patient selection of a live accepted hold; no FREE-to-committed or Doctor-ID bypass exists.

## 4. Hard UI boundaries

- Use synthetic static data only until separately authorized integration.
- Do not connect the new P4 UI to legacy urgent/consultation endpoints.
- Do not reuse scheduled-care submission for P4 CABINET.
- Do not disclose Patient identity, exact location, free text, voice or peer offers to an uncommitted Doctor.
- Do not return raw Doctor availability coordinates to Patient UI.
- Keep voice disabled.
- Keep CABINET arrival/no-show UI blocked pending the approved mechanism.
- End P4 at physical arrival plus `CLINICAL_HANDOFF_PENDING`; P5 owns verification, grants, medical records and consultation.
- Do not hard-code `K=2 / TTL=120` as production policy.

## 5. Exact next implementation task

Proceed only with **P4-UI-01A — Typed Synthetic Urgent Journey Foundation and Safe Route Cutover** as specified in the implementation plan. It must be Flutter-only, API-free and fixture-driven; centralize the P4 route; encode the four errata; preserve current visuals; and make legacy consultation, scheduled CABINET submission, QR/grant, medical-record and MRS continuations unreachable from the new P4 flow.

No production P4 API wiring should begin until the complete static HOME and CABINET state matrices, Doctor admission states, privacy projections, localization/accessibility checks and blocked CABINET arrival boundary pass review.

**P4-UI-00 STATIC UX INSPECTION COMPLETE — P4-UI-01A IS THE NEXT AUTHORIZED DESIGN TASK**
