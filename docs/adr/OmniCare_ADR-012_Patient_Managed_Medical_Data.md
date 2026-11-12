# ADR-012 — Patient-managed medical data: MRS only, item author, patient-declared medications

**Status:** Accepted (CTO, 2026-11-11 23:43)
**Date:** 2026-11-11
**Version:** 1.0
**Deciders:** CTO (Mechergui)
**Context documents:** ADR-001 v1.1 (invariant: medical content only in MRS), ADR-003 v1.1 Accepted (§4.2 pull-only consent, §7.2 life-safety override, §11.3 family records), ADR-004 v1.0 Proposed (encryption), ADR-006 (audit), Module 02 (§3.3 `passport_medications`, §4.2 `mrs_passport_records`), Module 03 §16, G-2 roadmap v1.20 (D-04, DATA-01), reports G2-FT-1 / FT-2 / FT-3.

> **Numbering note.** D-04 ("MRS is the source of truth") was planned as an ADR-004 amendment. ADR-004 covers encryption mechanics and is still Proposed, so data ownership gets its own ADR. ADR-008 to ADR-011 are reserved by ADR-001 §11, so this is ADR-012.

---

## 1. Context

**The problem in one sentence:** a patient can enter an allergy and never see it in his own record, and the doctor never sees it either.

- **Three places hold patient medical data today.**
  - Onboarding, Ma Santé and the family-member screen write to old main-database tables (`passport_*`, through `PATCH /api/v1/profile/passport` and `/profile/family-members/{id}/passport`), in **plain text**.
  - The « Dossier médical » screen reads MRS (G2-FT-1), with a fallback to the old columns for SELF only.
  - Doctors read and write MRS during consultations.

  This breaks the invariant "medical content lives only in MRS" (DATA-01), and it is a clinical-safety risk.
- **The CTO wants patients to edit their record.** A patient views, adds, edits and deletes his own record, and the record of the family member he selects, using the current UI.
- **Doctors write to the same record** (G-1: allergies with three states). We need a rule about who may delete what.
- **Patients take medications prescribed outside OmniCare.** Module 03 §16 deferred "patient-added medications" to Phase 2, because patient-reported data needs to be distinguished from prescriptions and needs a legal review. The CTO pulls it into V1.
- **The current editor has no « Aucune connue » button.**
- **Constraint:** every environment holds test accounts only; there are no real patients.

## 2. Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| A. Keep writing both the old tables and MRS | No backend change | Two truths that drift; plain-text health data stays; reads and writes disagree | ❌ |
| B. MRS only, items without an author | Simple | A patient can delete an allergy a doctor recorded, so the next doctor never sees it | ❌ unsafe |
| **C. MRS only, every item records its author (patient or professional), plus a patient-declared medication track** | One truth; the patient controls only what he entered; doctors know what is self-reported | MRS schema change (append-only migration); G-1 writes must set the author | ✅ **chosen** |

**Old data:** migrating the old tables into MRS is only worth it for real patients. There are none, so we **don't migrate**. The old columns are emptied before launch.

## 3. Decision

We will make **MRS the only store for patient medical data**, with these rules:

1. **One write path.**
   - Every patient-side write goes through Spring patient routes to MRS: onboarding, the record editor, Ma Santé and the family-member screen.
   - The old medical columns are no longer read or written. The SELF fallback added in FT-1 is removed.
   - The old columns are emptied before launch by an **audited admin command** (never manual SQL). No migration.
   - `/api/v1/passport/**` stays `denyAll`.
2. **Subject scope** (ADR-003 §11.3).
   - Every read and write carries `subject=SELF|FAMILY:{familyMemberId}`. The server checks that the caller owns that subject and returns the same 404 for "not yours" and "not found".
   - The app never sends an MRS id. An edit applies only to the selected subject. The default subject is SELF.
3. **Item author.**
   - Each allergy, condition and medication stores `authorType` (`PATIENT` | `PROFESSIONAL`), an internal author id, and created/updated times.
   - The patient may edit or delete only `PATIENT` items of the selected subject. `PROFESSIONAL` items are read-only for him.
   - **Blood type** follows the same rule through "last set by": once a professional sets it, the patient can no longer change it.
   - **Height and weight** change over time, so the patient can always update them; "last set by" is still recorded.
   - Items that already exist without an author count as `PROFESSIONAL` (safe default).
4. **Three-state lists.** Each list (allergies, conditions) has a status: `UNKNOWN` | `NONE_KNOWN` | `LIST`. When the editor saves:
   - a section the patient didn't touch → unchanged;
   - the patient removed all his items and no professional item remains → `NONE_KNOWN`;
   - at least one item → `LIST`.
5. **Patient-declared medications.**
   - The patient may add, edit and delete medications **prescribed outside OmniCare** (`authorType=PATIENT`, `source=PATIENT_DECLARED`).
   - They are shown with « Déclaré par le patient » to the patient and to professionals.
   - Medications prescribed through OmniCare (`source=PRESCRIPTION`) are read-only for the patient.
   - This overrides the Module 03 §16 deferral. The label is the required distinction; the legal review is still owed.
6. **Life-safety data stays visible** (ADR-003 §7.2, unchanged). The patient cannot hide allergies, blood type or critical conditions he opted in. The lock toggle hides **consultations** only.
7. **Validation, concurrency and audit.**
   - **Validation:** the server is the authority (Spring Bean Validation plus MRS validation); the app checks first only to give instant messages.
   - **Clinical ranges** (height, weight) are configurable, marked **REQUIRES MEDICAL VALIDATION**, and are soft warnings until a named doctor signs them off. Impossible values are hard errors.
   - **Concurrency:** writes carry an Idempotency-Key and an optimistic version per section. A conflict returns 409, and the app shows « Votre dossier a été modifié ailleurs, rechargez ».
   - **Audit:** every write is audited as ATTEMPTED / COMPLETED / FAILED, with subject, author type and purpose (ADR-006). No health values appear in logs, URLs or push payloads.

## 4. Consequences

- **Easier:**
  - one truth, so what the patient enters is what he and the doctor see;
  - the app loses its legacy save paths;
  - plain-text health data disappears from the main database.
- **Harder:**
  - **MRS schema change:** author fields, list status, medication source and section version. That means an append-only migration and a schema version bump (Module 02 §4.2 v1 → v2);
  - G-1's consultation writes must set `authorType=PROFESSIONAL`;
  - doctor views must show « Déclaré par le patient ».
- **Test accounts:** old test accounts show « Non renseigné » for data entered before. The CTO tests with a new account.
- **Follow-ups:**
  - G-2.1 Step 2 inspection, then the backend build (security review first), then app wiring;
  - G-1 coordination on authors and labels;
  - the purge command before launch (added to the G-2 gate);
  - the legal review of patient-declared medications (CEO);
  - updates to Module 02 §4.2/§3.3 and Module 03 §16.

## 5. Security and compliance impact

- **Authorization:**
  - the subject-ownership and author rules are enforced on the server (Spring and MRS), never only in the app;
  - every route gets "allowed" and "denied" tests: own subject, own family member, foreign family member, a professional item, a doctor calling a patient route.
- **Encryption:** unchanged; the ADR-004 envelope applies to the new fields because they live inside the encrypted record.
- **Audit:** every write is audited (ADR-006). The audit stores the author type and the subject, never the values.
- **Privacy (Law 2004-63 / INPDP):**
  - minimisation improves, because the plain-text copies are removed;
  - the patient can correct what he entered. For professional entries, the correction path is a Phase 2 "ask a correction" flow;
  - the exact legal articles are **unverified**: to confirm with counsel.

## 6. Self-roast

1. **A patient cannot fix a wrong allergy a doctor entered.** Accepted for V1; a correction request comes in Phase 2. It is safer than letting a patient delete a doctor's entry.
2. **The "last set by" rule on blood type can block a legitimate correction.** Same answer as #1.
3. **"Removed everything = none known" could happen by accident.** Mitigated: it applies only to a section the patient actually touched, and the doctor sees "déclaré par le patient" with the date. Accepted.
4. **Patient-declared medications are unverified.** Mitigated by the label; doctors must not treat them as verified. Legal review owed (CEO).
5. **A doctor and a patient can edit the same list at the same time.** Mitigated by the per-section version and the 409 reload message.
6. **The purge before launch could be forgotten.** Mitigated: added to the G-2 release gate (§8 of the roadmap).
7. **G-1 might write without setting the author.** Mitigated: a missing author counts as `PROFESSIONAL` (safe default), and G-1 is informed.

## 7. Approval checklist (CTO) — all approved 2026-11-11 23:43

1. ✅ MRS is the only store for patient medical data. The old columns are no longer read or written, and are emptied before launch by an audited command. No migration (test accounts only)
2. ✅ Every read and write is scoped to the selected subject (SELF by default, or one family member)
3. ✅ Each allergy, condition and medication records its author. The patient edits or deletes only his own items. Blood type locks once a professional sets it; height and weight are always editable
4. ✅ Three-state lists: untouched = unchanged; emptied = « Aucune connue »
5. ✅ The patient may declare medications prescribed outside OmniCare, labelled « Déclaré par le patient ». OmniCare prescriptions are read-only for him
6. ✅ Allergies, blood type and opted-in critical conditions cannot be hidden; the lock hides consultations only
7. ✅ Server-side validation; clinical ranges configurable and REQUIRES MEDICAL VALIDATION; idempotent writes with a 409 conflict message; every write audited
8. ✅ Accepted risks: #1, #2 and #3 above, plus the legal review of patient-declared medications still owed (CEO)

## Sources

- OWASP ASVS (authorization, input validation): https://owasp.org/www-project-application-security-verification-standard/
- OWASP Mass Assignment / authorization cheat sheets: https://cheatsheetseries.owasp.org/
- Internal: ADR-001 v1.1, ADR-003 v1.1, ADR-004 v1.0, ADR-006, Module 02, Module 03, G-2 roadmap v1.20.
- Law 2004-63 / INPDP: articles not verified here; confirm with counsel.

## 8. Implementation decisions recorded with the approval (G-2.1 D1–D5, CTO 2026-11-11 23:43)
- D1: the patient QR exists only during an active consultation (G-1 freeze kept).
- D2: the record editor gets an « Allergies » section reusing the existing chip widget; « Allergie Pénicilline » moves there; both preset lists REQUIRES MEDICAL VALIDATION.
- D3: patients view their own documents through a watermarked view-session; raw download stays blocked.
- D4: an expanded history card shows date, doctor, specialty, reason and that consultation's finalized documents; no diagnosis or notes.
- D5: patient edits call MRS synchronously (outside DB transactions, Idempotency-Key); the outbox stays for system jobs.

*Version 1.0 — ADR-012 — 2026-11-11 — Accepted.*
