# P1 Patient Doctor Directory

## Authority boundary

The Patient Doctor directory sends typed search criteria to
`GET /api/v1/doctors/search`. The backend owns professional visibility,
verification eligibility, matching, same-Cabinet predicates, ordering, and
pagination. Flutter does not load all Doctors and then apply authoritative
filters locally.

Care capability is configured service capability; it is not live online or
urgent availability. `CNAM accepté` and private-insurance acceptance are Cabinet
declarations, not verified convention or reimbursement guarantees. Ratings and
reviews are absent until a certified Reviews backend is adopted.

## Data flow

`WhoNeedsCareScreen` keeps the selected SELF or FAMILY MEMBER subject for later
navigation, then opens `DoctorDirectoryScreen`. Directory search never sends a
Patient or MRS identifier.

`DoctorDirectoryScreen` delegates to `DoctorDirectoryController`, which builds a
`DoctorSearchCriteria` and calls `DoctorDirectoryRepository`. The repository
maps transport failures to patient-safe errors, while `DoctorDirectoryApi`
decodes the typed P1-06 response. Widgets never issue HTTP requests.

Selecting a result navigates with its real `doctorId`. Doctor Detail remains a
separate refreshable API flow.

## Search and filters

Text search uses backend `q` after a 350 ms debounce. Request generations and
Dio cancellation prevent an older response from replacing newer search/filter
state.

The filter sheet exposes only backend-supported discovery criteria:

- specialty as exact backend free text; no invented taxonomy;
- governorate and city from the established Patient Tunisia location catalog;
- an intentional, permission-gated distance radius;
- one configured care capability;
- `ACCEPTED` declarations for CNAM or general private insurance;
- accepting new patients.

Location permission is not requested when the directory opens. It is requested
only after the Patient applies a distance radius. Flutter sends `lat`, `lng`, and
`maxDistanceKm`; it does not calculate authoritative distance locally.

## Pagination and matching Cabinet

The endpoint returns `{content, page, size, hasNext}`. Page zero resets paging.
The controller prevents concurrent next-page calls, deduplicates by `doctorId`,
stops when `hasNext` is false, and preserves loaded Doctors when a later page
fails. Pull-to-refresh retains current search and filter criteria.

Cards render only search-response fields: display name, specialty, `photoUrl`
with initials fallback, experience, optional consultation price, accepting-new-
patients state, up to two capability indicators, server distance, and the
returned matching Cabinet summary. Cabinet UUIDs are never shown. Static
ratings/reviews and static online status are not present.

## Legacy and deferred work

The primary Patient directory no longer calls legacy `GET /api/v1/doctors`.
Older mock-backed `DoctorsApi` consumers elsewhere in the pre-P1 request UI and
Doctor demo code are outside this directory adoption and remain documented
technical debt.

P1-08B owns Doctor Detail authority and redesign. Existing detail-only demo
Cabinet presentation metadata was intentionally not broadened or redesigned by
P1-08A.
