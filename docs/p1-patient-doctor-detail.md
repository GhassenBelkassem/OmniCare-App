# P1-08B Patient Doctor Detail backend integration

## Scope and authority

The Flutter Doctor Detail UI is frozen. This integration changes data sources
and state wiring only; it does not change layout, spacing, typography, color,
cards, icons, animation, tabs, section order, navigation, filters, or responsive
styling.

`GET /api/v1/doctors/{doctorId}` is authoritative for the Doctor profile and
Cabinet data connected here. Missing attributes stay absent and are reported;
the Flutter layer does not infer or manufacture them. Ratings/reviews,
scheduling changes, appointment changes, and urgent runtime changes are
deferred to their owning modules.

The contract was inspected directly in these backend sources:

- `DoctorDirectoryController#getDoctor`
- `DoctorDetailResponse`
- `DoctorEducationResponse`
- `DoctorCertificationResponse`
- `DoctorPracticeLocationResponse`
- `DoctorPracticeMediaResponse`
- `DoctorEquipmentResponse`
- `PublicPracticeCoverageResponse` and `CoverageClaimResponse`
- `DoctorDirectoryService#getById`

## Final data flow

```text
Doctor Directory card
  -> backend doctorId
  -> DoctorDetailScreen(doctorId)
  -> DoctorDirectoryController.fetchDetail(doctorId)
  -> DoctorDirectoryRepository.getDoctor(doctorId)
  -> DoctorDirectoryApi GET /doctors/{doctorId}
  -> DoctorDirectoryDetail.fromJson (typed DTO graph)
  -> buildDoctorDetail (presentation mapping)
  -> existing Doctor Detail widgets
```

The existing appointment-availability request remains a separate pre-existing
flow. It is not derived from the Doctor detail response and was not expanded in
P1-08B.

## Existing Doctor Detail UI inventory

| Existing UI attribute | Previous production source | Certified detail field available? | P1-08B action |
| --- | --- | --- | --- |
| Portrait | Empty/demo presentation catalog | Yes: `photoUrl` | Connected to network image; initials remain the visual fallback |
| Doctor name | Detail DTO | Yes: `displayName` | Kept connected |
| Verified badge | Detail DTO | Yes: `verified` | Kept connected |
| Specialty | Detail DTO | Yes: `specialty` | Kept connected |
| Sub-specialties | Detail DTO | Yes: `subSpecialties` | Kept connected |
| Experience | Detail DTO | Yes: `experienceYears` | Kept connected |
| Header location | Fabricated Cabinet from `practiceCity` | Yes: first `practiceLocations[].city` | Connected to the first returned Cabinet; no fabricated Cabinet fallback |
| Header distance | Presentation model | No usable detail value (`distanceKm` is null and Cabinet detail has no distance) | Remains absent; report gap |
| Languages | Detail DTO | Yes: `languages` | Kept connected |
| New-patient acceptance | Detail DTO | Yes: `acceptingNewPatients` | Kept connected |
| Next availability | Separate availability endpoint | No, not in Doctor detail | Existing separate integration unchanged; not inferred from detail |
| Areas of care | Detail DTO | Yes: `areasOfCare` | Kept connected |
| Expertise | Detail DTO | Yes: `expertise` | Kept connected |
| Visit reasons | Detail DTO | Yes: `visitReasons` | Kept connected |
| Patient age groups | Detail DTO | Yes: `patientAgeGroups` | Kept connected |
| Consultation options | Detail DTO | Yes: `consultationTypes` | Kept connected; not inferred from capabilities |
| Biography | Detail DTO | Yes: `biography` | Kept connected |
| Availability days/slots | Separate availability endpoint | No, not in Doctor detail | Existing separate integration unchanged |
| Cabinet gallery | Local demo clinic gallery | Yes: `practiceLocations[].gallery[].url` | Connected to real network URLs; demo gallery removed |
| Cabinet name | Fabricated from Doctor name | Yes: `practiceLocations[].name` | Connected |
| Cabinet address | Static `Adresse non renseignée` | Yes: `practiceLocations[].address` | Connected |
| Cabinet city | Legacy `practiceCity` fallback | Yes: `practiceLocations[].city` | Connected |
| Itinerary CTA | No-op | Coordinates exist | Left unchanged; navigation/maps behavior is outside P1-08B |
| Equipment labels | Static `ECG` | Yes: `practiceLocations[].equipment[].displayName` | Connected; quantities are not invented |
| Opening hours | Static weekday/hour rows | No | Static rows removed from production authority; report gap |
| Wheelchair accessibility | Static `Accessible PMR` | Yes: `wheelchairAccessible` | Connected only when true |
| Coverage | Empty/static-capable list | Yes: structured Cabinet `coverage` | Connected with explicit professional-declaration wording |
| Appointment instructions | Static instruction | Yes: `patientInstructions` | Connected |

The current screen has no rating, review count, review list, or rating summary
surface.

## Backend contract classification

### A. Existing Flutter UI already has a place

`displayName`, `photoUrl`, `specialty`, `verified`, `subSpecialties`,
`experienceYears`, `languages`, `acceptingNewPatients`, `areasOfCare`,
`expertise`, `visitReasons`, `patientAgeGroups`, `consultationTypes`,
`biography`, Cabinet `name/address/city`, `gallery.url`,
`wheelchairAccessible`, `patientInstructions`, `equipment.displayName`, and the
three structured coverage declarations.

### B. Backend field exists but the locked UI does not show it

`affiliatedClinicId`, `availableForUrgent`, `consultationPriceTnd`,
`phoneNumber`, `isActive`, `practiceCity`, `education`, `certifications`,
`careCapabilities`, Cabinet `id/type/governorate/latitude/longitude/publicPhone/
primary`, media `displayOrder`, equipment `code/portable`, coverage provenance,
coverage verification, and the specific-private-insurer-details flag. Cabinets
after the first are retained in state but not selectable by the current UI.

### C. Flutter UI expects data the detail endpoint does not provide

Opening hours, calculated Cabinet distance, schedule slots, and next-slot
labels. Scheduling data is owned by the separate appointment-availability
contract, not the Doctor detail contract.

### D. Flutter static/demo data audited

The former fabricated Cabinet name/address, opening hours, ECG, accessibility,
patient instructions, and clinic-demo gallery were removed from the production
Doctor Detail mapping. Test fixtures remain synthetic by design and are not
production data sources.

### E. Future or separate modules

Ratings/reviews, schedule evolution, appointment booking evolution, map-route
launch behavior, and urgent online/ETA runtime remain outside P1-08B.

## Table A — Flutter UI requires but backend detail does not provide

| UI field | Expected meaning | Current source | Backend available? | Likely owning module/phase | Recommended next action |
| --- | --- | --- | --- | --- | --- |
| Opening hours | Public hours for a Cabinet | No production value after demo removal | No | Practice scheduling/profile | Leave section hidden until a certified field exists |
| Cabinet distance | Distance from Patient/search origin | No value on detail; legacy top-level `distanceKm` is null | No usable detail value | Directory/location search | Pass a certified matching-location distance or extend the detail contract intentionally |
| Availability days and slots | Bookable schedule | Separate `/appointments/availability/slots` flow | Not in detail | P2/P3 scheduling | Keep semantically separate; never infer from capability |
| Next availability | Earliest bookable slot | Derived from separate slot response | Not in detail | P2/P3 scheduling | Keep semantically separate; never infer from capability |
| Itinerary action | Launch navigation to Cabinet coordinates | Existing button has no action | Coordinates only; no CTA contract | Navigation/maps | Define the product navigation contract before wiring the CTA |

Ratings/reviews are not listed as a current UI requirement because the locked
Doctor Detail screen does not render them. The certified backend still has no
ratings/reviews domain.

## Table B — Backend provides but Flutter UI does not currently expose

| Backend field/domain | Current UI support | Should it potentially be added later? | Reason |
| --- | --- | --- | --- |
| `affiliatedClinicId` | None | Maybe | Requires an intentional Clinic relationship design |
| `availableForUrgent` | None | Not in P1-08B | Capability/runtime semantics require urgent-domain ownership |
| `consultationPriceTnd` | None | Maybe | Price display needs approved product semantics |
| `phoneNumber` | None | Maybe | Contact action and privacy behavior need design approval |
| `isActive` | None | No direct display | The endpoint visibility contract already gates public Doctors |
| `practiceCity` | No direct surface after structured Cabinets | No | Structured `practiceLocations` are authoritative |
| `education[]` | None | Yes | Locked UI has no education surface |
| `certifications[]` | None | Yes | Locked UI has no certification surface |
| `careCapabilities[]` | None | Yes | Needs labels that do not imply schedule or live availability |
| Cabinets after index 0 | Stored, not selectable | Yes | Current UI assumes one Cabinet while backend supports 0..N |
| Cabinet `id`, `type`, `governorate`, `publicPhone`, `primary` | None | Maybe | Useful for multi-Cabinet selection/contact later |
| Cabinet coordinates | No presentation; itinerary CTA remains no-op | Yes | Could support an approved maps integration |
| Gallery `displayOrder` | Ordering only | No direct display | Used implicitly by backend ordering |
| Equipment `code`, `portable` | Label only | Maybe | Current surface only presents equipment names |
| Coverage provenance/verification | Wording indicates declaration; flags not shown | Maybe | Any badge would require legal/product review |
| Specific insurer detail availability | None | Later | Backend currently guarantees no named-insurer details |

## Table C — static/demo Flutter values remaining

| Field | Location | Why it exists | Real backend replacement available? | Future owner |
| --- | --- | --- | --- | --- |
| French section titles, empty-state copy, and icon choices | `doctor_detail_screen.dart` | Locked presentation copy/chrome, not domain data | Not applicable | Future UX phase only |
| Availability date/time labels | Existing availability mapper/widgets | Formatting of real slot instants | Already backed by the separate slots API | Scheduling |
| Test Doctor/Cabinet fixtures | Flutter test files | Deterministic automated tests | Not applicable to production | Test infrastructure |

No production Doctor or Cabinet attribute now falls back to a demo name,
address, gallery, hours, equipment item, accessibility claim, coverage claim,
or appointment instruction.

## Capability and domain notes

- `CABINET`, `HOME_VISIT`, `URGENT_HOME`, and `URGENT_CABINET` are parsed as
  controlled capability values and retained in typed state. They are not
  interpreted as online, available now, scheduled, or an ETA.
- Public Cabinet equipment only is parsed. No quantity is invented and private
  mobile equipment is not exposed.
- Coverage labels explicitly say they are professional declarations. They do
  not claim CNAM convention status, Patient eligibility, reimbursement, direct
  billing, or named-insurer acceptance.
- Education and certifications are parsed and retained but not rendered because
  the locked UI has no surface.
- All returned Cabinets are parsed. The current UI still presents only the
  first (backend orders the primary Cabinet first), which is a deliberate UI
  capability gap for later design.

## UI freeze review

`doctor_detail_screen.dart` changed only to bind the existing portrait and
gallery widgets to backend network URLs, pass the real first Cabinet to the
existing Cabinet tab, remove the false demo-gallery caption, and preserve the
existing full-screen gallery interaction for network images. No style token,
layout measurement, spacing, typography, color, icon, animation, tab, section
order, filter, or navigation structure changed.

`doctor_presentation_metadata.dart` no longer contains Doctor-specific demo
portraits or Cabinet gallery data; it retains only the source-aware image value
used by the existing widgets.

UI/UX redesign changes: **NONE**.
