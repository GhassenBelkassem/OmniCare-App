# P1 Flutter integration gap register

## Purpose and authority

This document freezes the remaining backend-to-Flutter presentation and domain
ownership gaps after P1-08A Doctor Directory and P1-08B Doctor Detail. It is a
register, not an implementation plan. The current Flutter UI is frozen; none of
the items below authorizes a new section, selector, badge, CTA, or workflow.

The authoritative P1 sources are the typed Doctor search/detail DTOs and the
separate appointment-availability contract. Missing values remain absent. A
configured capability must never be presented as live availability, an online
state, a bookable slot, or an ETA.

## UX/UI presentation

| Gap | Current state | Owner / decision |
| --- | --- | --- |
| Multiple Cabinets | Every backend `practiceLocations[]` entry is parsed and retained, but Doctor Detail presents only the first backend-ordered Cabinet. | Dedicated future UX/UI phase; define selection, primary-Cabinet semantics, and navigation continuity. |
| Education and certifications | `education[]` and `certifications[]` are typed and retained but the locked detail screen has no surface. | Future Doctor profile UX/UI. |
| Care capabilities on detail | Typed values are retained. Directory cards show at most two configured capability labels; Doctor Detail does not show the full set. | Future Doctor profile UX/UI; wording must not imply schedule or live state. |
| Detail consultation price | `consultationPriceTnd` is shown on directory cards when supplied, but the locked detail screen has no price surface. | Future pricing/product UX decision. |
| Doctor public phone | `phoneNumber` is retained but not presented. | Future contact/privacy UX decision. |
| Cabinet attributes | Cabinet `governorate`, `publicPhone`, and `primary` are retained but not directly presented on Doctor Detail. Directory matching summaries may show a returned governorate. | Multi-Cabinet/contact UX phase. |
| Equipment metadata | Equipment labels are presented; `code` and `portable` are retained but not shown. | Future Cabinet-detail UX only if useful. |
| Gallery ordering metadata | Backend order is preserved; `displayOrder` has no direct visual label. | No UI needed unless media-management requirements change. |
| Affiliated Clinic relationship | `affiliatedClinicId` is retained by the detail contract but has no patient-facing relationship surface. | Future Doctor/Clinic relationship design. |

## P2/P3 scheduling

| Gap | Current state | Owner / decision |
| --- | --- | --- |
| Opening hours | Doctor Detail has an existing hours section, but the certified Doctor detail payload supplies no opening-hours field; the former static rows remain removed and the section stays hidden. | P3 practice schedule/profile authority. |
| Availability slots | Slots are already loaded from the separate `/appointments/availability/slots` contract and rendered by the existing availability flow; they are not Doctor-detail fields. | P2/P3 scheduling owns contract and behavior evolution. |
| Next available slot | Flutter derives the current label from the earliest returned real slot; it is not inferred from care capabilities or Doctor detail. | P2/P3 scheduling owns future server semantics and timezone/product decisions. |
| Booking evolution | Current slot selection/booking remains separate from P1 Doctor profile adoption. | P2/P3 appointment and scheduling work. |

## P4+ urgent

| Gap | Current state | Owner / decision |
| --- | --- | --- |
| Urgent online state | `availableForUrgent` and `URGENT_*` care capabilities describe eligibility/configuration, not a live online state. No online badge is fabricated. | P4-P6 urgent orchestration. |
| Urgent ETA and dispatch | Doctor search/detail provides no authoritative ETA, dispatch state, or arrival estimate. | P4-P6 urgent matching/dispatch. |

## Ratings/Reviews

The certified Doctor search/detail contracts provide no rating aggregate,
review count, or review list, and the locked Patient Doctor screens render none.
Any future rating or review presentation belongs to the Reviews module and must
use that module's authoritative moderation and aggregation semantics.

## Navigation/maps

Cabinet latitude and longitude are parsed and retained. The existing itinerary
control has no navigation action. A future maps decision must define provider,
permission, missing-coordinate, multi-Cabinet, and external-app behavior before
the CTA is wired. P1 must not infer a route or add a map.

## Insurance

The current Cabinet section presents only structured CNAM, general private-
insurance, and self-pay acceptance values, explicitly worded as professional
declarations. Coverage provenance and verification flags are not directly
surfaced. Named/specific insurers are not available from the current public
contract; `specificPrivateInsurerDetailsAvailable` is retained as contract
state but is not a substitute for insurer data. Any badges, verification claim,
eligibility statement, reimbursement promise, or named-insurer UI requires a
future insurer/legal/product integration decision.

## Other

| Gap | Current state | Owner / decision |
| --- | --- | --- |
| Detail Cabinet distance | Search may return an authoritative matching distance, but Doctor detail does not provide a usable calculated distance. The detail screen therefore shows city without inventing distance. | Future directory-to-detail context or location-contract decision. |
| Top-level `practiceCity` | Retained by the backend DTO but not used as a fallback over structured Cabinets. | No UI action; structured `practiceLocations[]` remains authoritative. |
| `isActive` | Retained but not displayed; public endpoint visibility is the user-facing gate. | Backend/public-directory policy. |
| Patient subject | Doctor Cabinet discovery preserves SELF or owned FAMILY MEMBER. OTHER PERSON remains limited to flows that explicitly own it; it is not added to this flow. | Request-domain ownership. |

## Static/demo authority freeze

The production Patient Doctor directory/detail path contains no authoritative
fake Doctor name, specialty, rating, review count, online state, address,
gallery image, equipment item, coverage claim, or Cabinet attribute. Initials,
icons, empty-state text, section titles, and patient-safe fallback copy are
presentation chrome rather than domain data. Synthetic values remain only in
tests. Legacy mock-backed Doctor consumers outside the Patient Doctor
directory/detail path remain separate technical debt and are not promoted as
P1 authority.

## Freeze decision

All entries above remain intentionally unimplemented in P1-08C. The gap
register does not change Flutter layout, navigation, filters, scheduling,
ratings, maps, insurance behavior, backend code, Angular code, or MRS code.
