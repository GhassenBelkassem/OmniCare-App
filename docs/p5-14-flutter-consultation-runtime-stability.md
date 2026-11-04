# P5-14 Flutter Consultation Runtime Stability

Recovery date: 2026-10-27
Scope: P5-14 Flutter Consultation runtime stability only.
Data handling: live database inspection was metadata-only. No clinical payload, credential, token, secret, or artifact body was read or reported. No live clinical write was made.

## 1. Final Status

`P5_14_FLUTTER_CONSULTATION_RUNTIME_STABLE`

`VERSION_WARNING_ROOT_CAUSE = D/F — a dirty refresh was labeled newer without an authoritative version comparison, and PrescriptionController reacted to clinical-record CONSULTATION_UPDATED invalidations`

`SCROLL_LOCK_ROOT_CAUSE = Laboratory order rendering inserted an OutlinedButton with an inherited infinite-width minimum into an unconstrained Row, causing a BoxConstraints-forces-an-infinite-width layout failure`

`LAB_ORDER_RUNTIME = FIXED`

The false warning and the post-Laboratory-create layout failure were reproduced in focused controller/widget tests, corrected without weakening optimistic concurrency or realtime invalidation, and verified at phone and simulator/tablet viewports. The live Consultation was not finished or clinically modified, and P5-15 was not started.

## 2. Version Warning Root Cause

The exact reported text, `A newer version is available. Your local draft was preserved.`, is owned by `PrescriptionCard._failure`, not the Clinical Record card or a shared Consultation banner.

Before the correction, both `PrescriptionController.load` and `ClinicalRecordController.load` treated `dirty && !force` as sufficient proof that a newer server version existed. They set `newerVersionAvailable = true` and returned without fetching authority or comparing versions. `PrescriptionController` listens to both prescription events and clinical-record `CONSULTATION_UPDATED` invalidations. Consequently, an ordinary clinical save, realtime refresh, resume, or reconnect could enter the dirty Prescription store and display this exact warning even when `prescriptionVersion` had not advanced.

The warning therefore did not establish `SERVER_VERSION > LOCAL_BASE_VERSION`. It inferred that condition solely from `dirty + refresh`. The exact classification is D/F: a self/current-state refresh was misclassified, and the Prescription store coupled a clinical dependency refresh to a prescription-content conflict.

## 3. Clinical Version State

Metadata-only inspection of Consultation `e97c7a54-e378-4d59-b656-5e15457cdc02` found:

| Version field | Value |
|---|---:|
| `Consultation.version` | 1 |
| MRS `clinicalRecordVersion` | 1 |
| Flutter clinical version on a current fresh load | 1 |
| Flutter clinical draft base on a current fresh load | 1 |
| MRS `prescriptionVersion` | 1 |
| Prescription expected `clinicalRecordVersion` | 1 |
| Clinical-record server `updated_at` | `2026-10-27T21:15:38.304646Z` |

The persisted Clinical Record and Prescription each have one active row. The screenshot-time in-memory base cannot be reconstructed because the app does not persist that transient telemetry. The old implementation did not compare it anyway. Although the aggregate and clinical versions are both currently 1, they are independent counters and are now handled as such.

## 4. Self-Save / Realtime Behavior

Clinical, Prescription, and Clinical Order controllers now queue invalidations that arrive while a save/finalize or load is in flight. A successful command adopts its response and new authoritative version first; only then is the queued refresh drained.

On refresh with a dirty draft:

- Clinical Record warns only when the fetched `clinicalRecordVersion` is greater than its authoritative local base.
- Prescription warns only when the fetched `prescriptionVersion` advances. A clinical dependency-version update at the same prescription version updates metadata while preserving the draft without warning.
- A Clinical Order editor warns only when that persisted order's own version advances. A same-version refresh or a new unsaved order editor is preserved without warning.

Optimistic locking, genuine cross-device conflict protection, and local-draft preservation remain active.

## 5. Prescription Coupling

The exact banner owner is `PrescriptionCard`. The Prescription API still carries its required clinical-record dependency version for finalization, but clinical dependency changes no longer masquerade as prescription-content changes. Prescription save/finalize responses are adopted before queued realtime work, so the same device cannot classify its own acknowledged version as an external conflict.

Clinical Record invalidation also continues to ignore prescription events and medical-access events. A higher Consultation aggregate version may cause a safe authority read when the event type is `CONSULTATION_UPDATED`, but the result is judged only by `clinicalRecordVersion`.

## 6. Scroll Architecture

`ConsultationDetailScreen` remains the single vertical scroll owner through one root `SingleChildScrollView`. It now owns one state-lifetime `ScrollController`, attaches it to that root, preserves it across Provider/ChangeNotifier rebuilds, and disposes it with the screen.

Clinical authoring, Prescription/Add medication, Laboratory, Imaging, Referral, artifacts, and Finish controls are ordinary children of this owner. The medication and order editors are inline; they do not use a nested `ListView`, `CustomScrollView`, `NestedScrollView`, `DraggableScrollableSheet`, `PageView`, or bottom sheet and do not take vertical gesture ownership.

## 7. Scroll Lock Root Cause

Creating a Laboratory order added `_OrderRow` to the real widget tree. Its Finalize `OutlinedButton` was inside a width-unconstrained `Row`, while the global Omni `OutlinedButtonTheme` supplies `minimumSize: Size(double.infinity, 50)`. Flutter then raised `BoxConstraints forces an infinite width` during layout. The broken render tree manifested as the reported inability to continue scrolling after Laboratory creation.

The Finalize button now overrides only its local minimum width with `Size(0, 50)`. No extra scroll view or arbitrary physics were added. Phone-width dropdown overflows discovered by the same runtime test were also corrected with `isExpanded: true` in the existing Clinical Authoring and medication-duration fields.

## 8. Keyboard / Focus

The root scroll view uses `ScrollViewKeyboardDismissBehavior.onDrag`. Add/remove/save medication and begin/cancel/save Clinical Order transitions explicitly release primary focus before mutating the inline editor. Runtime tests focus a multiline clinical field, drag with focus active, dismiss the keyboard, and continue through the rest of the page in both supported viewports.

## 9. Medication Modal

Add medication is not a modal or bottom sheet; it appends an inline medication editor. It creates no modal barrier, sheet controller, or gesture-capturing overlay. Add, input, save, and subsequent page scrolling pass. Tests assert that the route's baseline `ModalBarrier` count does not increase after editor operations.

## 10. Laboratory Order Runtime

`LAB_ORDER_RUNTIME = FIXED`

The real Laboratory UI path opens the inline editor, keeps the input reachable, cancels and reopens, creates through the existing P5-10 controller/API contract, closes the editor, displays the new order, and remains scrollable into Official artifacts and Finish. Imaging and Referral open/cancel behavior was verified through the same path. No P5-10 contract or visual redesign was introduced.

## 11. Controller Lifecycle

The page `ScrollController` is created once in State and disposed once. Existing text controllers and focus state are not recreated by clinical, prescription, order, realtime, medical-access, or resume rebuilds. The runtime test verifies that scroll offset remains usable through editor mutations and a valid inactive/hidden/paused/hidden/inactive/resumed lifecycle sequence.

## 12. Fixes Applied

- Replaced dirty-refresh shortcuts with authoritative resource-version comparisons in Clinical Record, Prescription, and Clinical Order controllers.
- Queued refreshes during save/finalize/load and drained them only after adopting successful responses.
- Preserved volatile drafts and genuine conflict warnings.
- Added a stable root ScrollController and drag keyboard dismissal.
- Released focus around inline medication/order transitions.
- Corrected the Laboratory result-row infinite-width Finalize button.
- Corrected phone-width dropdown overflows without redesigning the UI.

## 13. Tests

Focused Flutter result: **44 passed**.

Coverage includes the 17 required behaviors: same-version clean/dirty refresh, self-save followed by realtime, unrelated aggregate and prescription changes, genuine external version advancement and draft preservation, full top-to-bottom scrolling, keyboard dismissal, Add medication add/save, Laboratory cancel/create, Imaging/Referral close, realtime/resume stability, and absence of a new invisible barrier. The canonical Consultation runtime test executes at `390 × 844` and `1024 × 768` with normal text scale and reaches artifacts and Finish controls without overflow.

Static analysis of the ten runtime-stability controller/card/test files reports no issues. `git diff --check` passes.

## 14. Manual Reproduction Result

The defects were converted into deterministic runtime reproductions using the real Consultation detail widget tree and safe fake APIs. Before the layout correction, Laboratory create produced the infinite-width Flutter exception; after the correction, both viewports complete the full interaction sequence. Controller tests reproduce the dirty-refresh warning trigger and prove that same/self refreshes no longer warn while genuine external advances still do.

A second live clinical write was intentionally not used for verification. Live validation was metadata-only to preserve the current synthetic Consultation and the user's work. No sharing policy, Consultation lifecycle, artifact, or Finish state was changed.

## 15. Remaining P5-14 Blockers

None for Flutter Consultation runtime stability. The live Consultation remains in progress and was not finished. P5-15 remains unstarted.
