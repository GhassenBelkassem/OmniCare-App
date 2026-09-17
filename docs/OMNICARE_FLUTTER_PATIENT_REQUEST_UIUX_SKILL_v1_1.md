# OmniCare Flutter Patient Request UI/UX Skill — v1.0

**Status:** Approved design reference for implementation agents  
**Version:** 1.1 — Flutter-only static-first UI redesign  
**Date:** 2026-08-18  
**Scope:** Flutter patient-facing Clinic Request experience  
**Primary use:** Reference/skill file for OpenCode or any coding model implementing UI/UX changes  
**Implementation authority:** Existing OmniCare Flutter functionality, authentication, routing, request workflow, privacy boundaries, and current source-of-truth module documents remain authoritative. This document governs the **presentation, interaction hierarchy, and reusable UI patterns** for the redesign only.

**Hard implementation boundary for v1.1:** This redesign is **Flutter UI only**. The backend and the existing Flutter Clinic Request API/network/repository contracts are frozen for this work. Do not modify them. Missing presentation data may be represented temporarily by static Flutter-only UI data as described in this document and replaced by real backend fields later.

---

## 1. Purpose

This document defines the target UI/UX language for the patient-facing OmniCare Clinic Request flow.

The redesign must transform the existing functional but static-looking screens into a polished, trustworthy, premium healthcare experience without changing the underlying business workflow.

The experience should make a patient feel:

- confident about which clinic they are choosing;
- reassured that the clinic is legitimate and capable;
- in control of the request they are about to send;
- clear about what happens next;
- calm rather than overwhelmed;
- that OmniCare is a high-quality healthcare product rather than a generic form application.

The UI should increase the **perceived value of the clinic** through strong presentation, useful information hierarchy, trust signals, photography, spacing, typography, and deliberate confirmation patterns.

This is inspired by two product-quality principles:

### Apple-style clarity

- clear hierarchy;
- strong orientation;
- native interaction patterns;
- reduced cognitive load;
- predictable controls;
- immediate feedback;
- accessibility and precision;
- only the information needed at the current decision point.

### Airbnb-style perceived value and trust

- present the object as an experience, not a database row;
- use photography and editorial hierarchy to create value;
- progressively reveal detail;
- build trust throughout the decision journey;
- explain why information matters;
- keep primary action available without repeatedly shouting at the user;
- make confirmation calm, clear, and reversible.

**Do not visually clone Apple or Airbnb.** Learn from their interaction principles and apply them to OmniCare healthcare.

---

# 2. Product principle

The Clinic Request flow is not an administrative form.

It is a guided care-selection journey:

```text
Who needs care?
    ↓
Choose a clinic
    ↓
Understand the clinic
    ↓
Select the clinic
    ↓
Provide/confirm request information
    ↓
Review the request
    ↓
Submit
    ↓
Understand what happens next
```

At each step, the patient should understand:

1. Where am I?
2. What am I deciding?
3. What information matters now?
4. Can I change my decision?
5. What will happen after I continue?

---

# 3. Non-goals

This redesign must **not**:

- change backend Clinic Request workflow semantics;
- modify the backend at all;
- modify existing Flutter Clinic Request API endpoint definitions, HTTP payloads, DTO contracts, repository networking behavior, or shared `AppHttpClient` behavior;
- introduce new backend calls for UI enrichment;
- add a parallel API/repository/networking layer;
- create fake clinic ratings;
- create fake availability promises;
- create fake review-speed claims;
- introduce medical diagnosis or clinical-record data into the Clinic Request flow;
- redesign authentication;
- redesign navigation architecture unless required to apply the approved visual shell;
- introduce a new state-management package;
- introduce a new networking package;
- introduce a new routing package;
- duplicate API calls solely for decoration;
- persist request/clinic operational data merely for UI convenience.

### Static-first rule for missing presentation data

For this UI phase only, when the current API does not expose presentation data such as specialties, gallery images, clinic type, map preview metadata, service chips, or richer descriptive content, the implementation may use **clearly isolated Flutter-only static presentation data**.

This static data is temporary UI scaffolding. It is not domain truth and must never alter request submission payloads, workflow decisions, security, eligibility, routing, filtering on the server, or business logic.

Preferred pattern:

```text
real API Clinic DTO
        +
Flutter-only presentation metadata keyed by stable clinic identity
        ↓
UI view model / presentation adapter
        ↓
Screen
```

Keep static enrichment in a dedicated presentation/demo fixture file or mapper, not inside API/repository classes and not scattered through widgets. It must be easy to delete when backend fields arrive later.

Static content may be used for:

- specialties;
- clinic gallery/demo images;
- clinic-type labels;
- service chips;
- optional descriptive/value copy;
- map preview/fallback presentation;
- filter metadata used only by the currently loaded Flutter list.

Static content must **not** be used for:

- medical information;
- ratings/reviews presented as real user evidence;
- response-time/SLA claims;
- availability guarantees;
- ranking presented as data-driven truth;
- security/verification claims not already true for OmniCare.

---

# 4. Existing Flutter architecture to preserve

The current Flutter app architecture is already certified and must be reused.

Known baseline:

- Flutter 3.41.x
- Dart 3.11.x
- Provider
- MaterialApp named routes
- Dio via shared `AppHttpClient`
- existing authentication/session pipeline
- secure token storage
- existing Clinic API/repository/controller patterns
- Plus Jakarta Sans already used in Flutter
- Material 3 foundation

Do not create parallel infrastructure for the redesign.

The UI agent may create reusable visual components and tokens, but should fit them into the current project structure and conventions after inspecting the actual repository.

## 4.1 Frozen API/network boundary

For this redesign, treat the existing Flutter API/network layer as read-only.

Do not modify:

- Clinic API endpoint paths;
- request/response payload shapes;
- HTTP query parameters;
- Clinic API methods merely to support richer UI;
- shared `AppHttpClient`;
- authentication/token behavior;
- backend Java code;
- backend DTOs/controllers/services/migrations.

Prefer UI composition over API changes.

If the current screen already receives enough real Clinic objects to render the flow, enrich those objects only in the presentation layer with temporary static metadata.

Existing API/repository files should remain untouched unless the task is fixing a proven pre-existing Flutter defect unrelated to UI enrichment. If such a defect is discovered, stop and report it rather than changing those files as part of this redesign.

---

# 5. Design personality

OmniCare should feel:

- calm;
- premium;
- modern;
- trustworthy;
- human;
- efficient;
- healthcare-specific without looking institutional;
- elegant without looking luxurious for luxury's sake;
- warm enough for patients, structured enough for healthcare.

Avoid:

- generic "AI dashboard" aesthetics;
- neon gradients;
- excessive glassmorphism;
- excessive shadows;
- mint/green on every element;
- huge rounded cards for every block;
- decorative charts;
- fake marketplace badges;
- oversaturated medical blue;
- sterile ERP styling;
- hospital-management density on patient screens.

---

# 6. Brand color direction

The redesign should unify the stronger current OmniCare brand direction.

## 6.1 Core brand colors

```text
Fresh Mint (brand/success)      #1FBF9A
Mint Soft (selected surface)    #EDFBF6
Primary Action (CTA teal)       #0F826D
Primary Action Pressed          #0C6F5F
Deep Teal (contrast over mint)  #0D473D
Slate Blue (structural)         #294B63
```

The **action teal** (`#0F826D`) is the primary high-emphasis CTA color because
white text stays clearly readable on it.

The **bright mint** (`#1FBF9A`) is a semantic accent reserved for:

- selected states;
- accepting requests / availability;
- success/positive confirmation;
- active indicators;
- small brand badges.

> **Do not use brand mint as the default color for generic icons, cards,
> placeholders or informational panels.** If an element is not a brand,
> selection, availability or success moment, it must not be mint.

## 6.2 Neutral surfaces

```text
Page background           white
Primary surface           white
Secondary surface         soft neutral slate #F2F7FA
Border                    low-contrast neutral
Primary text              deep navy/slate #1D2939
Secondary text            muted slate
Disabled text             low-emphasis neutral
```

White is the primary canvas. Large gray page backgrounds are avoided.

## 6.3 Semantic color roles

Every color used in the Clinic Request flow must carry a semantic role.
Never pick a color just because it "looks nice".

```text
GREEN / MINT    brand, success, accepting requests, selection, active state
ACTION TEAL     high-emphasis CTA (Continue, Apply, Select, Submit)
BLUE            information, location, guidance, process/instructions
CYAN            clinical data, medical services, health data
VIOLET          identity, specialties, records/documents (restrained)
AMBER           pending, waiting, warning, not accepting requests
CORAL           urgent / high-attention (future Request screens)
RED             error / destructive only
SLATE           structural, navigation, neutral iconography, placeholders
WHITE           main canvas
```

Rules:

- Placeholders for missing imagery use **slate**, never mint.
- Location pins/panels use **blue**; services use **cyan**; specialty chips use
  restrained **violet**; accepting/selection use **mint**.
- Use mostly soft backgrounds + colored text/icon/border; avoid several
  saturated hues in one viewport (2–3 meaningful accent families is enough).
- Status is never communicated by color alone (dot + label text always).
- Never put white text on bright mint `#1FBF9A`; use the darker action teal
  for white-text CTAs.

The Flutter theme (`lib/core/theme/omni_theme.dart`) is the executable source
of truth for these tokens; this skill is the design-guidance source of truth.

---

# 7. Typography

Use **Plus Jakarta Sans** unless the current repository has an approved replacement.

Typography should do most of the hierarchy work.

Use a small controlled hierarchy:

```text
Page title
Section title
Card/list title
Body
Secondary body
Label
Caption
Button label
```

Principles:

- avoid too many font weights;
- avoid oversized titles that consume the viewport;
- use dark, high-contrast headings;
- use muted secondary copy;
- keep line lengths readable;
- avoid technical jargon;
- use sentence case for patient-facing labels;
- keep button text short and action-oriented.

The redesign must feel editorial and deliberate, not like each screen chose its own font sizes.

---

# 8. Spacing and density

The current request flow has too much dead space in some areas and oversized containers for small amounts of information.

Target:

- generous but intentional whitespace;
- more useful information above the fold;
- clear section rhythm;
- no cramped mobile tables;
- no giant empty hero blocks without valuable imagery;
- no oversized single-row cards.

Use a consistent 4px-based spacing system where the existing app allows it.

Typical spacing scale:

```text
4
8
12
16
20
24
32
40
```

Do not invent arbitrary spacing per screen.

---

# 9. Corners, surfaces, and elevation

Rounded geometry is part of the OmniCare personality, but **not everything should be a card**.

Use hierarchy like this:

- content sections can sit directly on the page;
- use dividers and spacing where enough;
- use cards when grouping is functionally useful;
- use pills/chips only for compact state or metadata;
- use bottom sheets for temporary focused choices;
- use sticky bottom action surfaces for commitment steps where appropriate.

Suggested radius direction:

```text
Controls / fields         12–14
Cards                     16–20
Large sheets              24+
Pills                      full pill radius
```

Use subtle elevation. Shadows should not make every card float aggressively.

---

# 10. Iconography

Use one coherent icon family.

Icons should have consistent:

- stroke weight;
- optical size;
- bounding box;
- alignment;
- active/inactive treatment.

Icons should explain concepts, not decorate.

Examples:

- person/family;
- clinic/building;
- location;
- specialty;
- calendar/availability;
- shield/privacy/trust;
- check/accepted state;
- filter;
- search;
- gallery;
- edit/change.

Do not mix unrelated illustration styles, filled icons, outline icons, and highly detailed icons in one navigation surface.

---

# 11. Navigation shell

The Clinic Request flow should not waste vertical space on repeated branding and low-frequency actions.

General rule:

### Root patient screens

May use:

```text
OmniCare / context            notification / profile
```

### Transactional sub-screens

Prefer:

```text
←   Page title                        contextual action
```

Do not place a bright Logout icon permanently beside notifications on every transactional screen.

Logout/account actions belong in Profile/account context.

The redesign should preserve actual routing behavior while simplifying visual chrome.

---

# 12. Bottom navigation

Bottom navigation must feel like one coherent system.

Requirements:

- same icon family;
- same icon size;
- same visual stroke weight;
- labels if needed for clarity;
- strong but restrained active state;
- no unrelated full-color brand logo used as an ambiguous navigation action unless the route meaning is extremely clear and already product-approved.

Do not redesign route semantics silently. If the current navigation item meaning is unclear, improve its visual label rather than inventing a new feature.

---

# 13. Screen 1 — Who needs care?

## 13.1 Goal

Allow the patient to select the subject of the request quickly and confidently.

Possible subjects:

- Self
- Existing family members

Backend/current profile rules remain authoritative.

## 13.2 Target hierarchy

```text
←   Who needs care?

Choose who this request is for.

Self
[avatar/icon]  Me
               My care request
               selected indicator

Family
[avatar]       Family member name
               Relationship

...

[ Continue ]
```

The helper text should be short. Do not create an oversized introductory header.

## 13.3 Selection design

The current selected-state pattern uses too many simultaneous signals.

Use a controlled selected state:

- subtle selected surface OR slightly stronger border;
- one clear selection indicator;
- small supportive accent.

Do not simultaneously use a thick green border + green icon + mint background + large green check unless the design system explicitly requires it.

## 13.4 Family member rows

Family members should feel like identities, not generic cards.

Show only useful information:

- display name;
- relationship;
- avatar/initial if available;
- selection state.

Keep rows compact enough that multiple family members can be scanned without excessive scrolling.

## 13.5 Continue action

Use one primary full-width action in a stable bottom area when appropriate.

Continue is enabled only when the current workflow requires a valid selection.

Do not add duplicate secondary CTAs.

---

# 14. Screen 2 — Choose a clinic

## 14.1 Goal

Make clinic discovery feel valuable, trustworthy, and easy to scan.

This is a **decision/discovery screen**, not an internal directory table.

## 14.2 Header

Approved compact pattern:

```text
←   Choose a clinic                           [filter]
```

Do not use a large explanatory paragraph under the title.

Optional helper text, if used, must be one short line only.

The filter icon sits on the same visual row as the page title or in the trailing app-bar/action location according to the actual Flutter shell.

## 14.3 Search

Use a refined search field with:

- search icon;
- text input;
- clear action when text is present;
- appropriate focus state;
- no oversized height;
- no excessive glowing border.

Search should remain fast and obvious.

## 14.4 Filter bottom sheet

Tapping Filter opens a modal bottom sheet.

Required behavior:

- appears from bottom;
- rounded top corners;
- tap outside dismisses;
- swipe down dismisses if consistent with current platform behavior;
- internal content scrolls if needed;
- bottom actions remain reachable;
- safe area respected;
- keyboard safe;
- active filters indicated on the main screen.

Suggested bottom-sheet structure:

```text
Filters

Specialty
[options]

Location / city
[options]

Accepting requests
[option]

Clinic type
[options if supported]

Services
[options if supported]

Distance / nearby
[only if real geolocation and backend support exist]

Sort
[nearest / recommended / accepting first / alphabetical]

[Reset]                  [Apply filters]
```

For this Flutter-only redesign, filters may use a mix of:

- fields already present in the current Clinic DTO; and
- isolated static presentation metadata defined by this skill.

Do not change or extend the API to support filtering.

Until backend filtering exists, filter only the clinics already loaded by the current Flutter flow. Make this implementation modular so the local predicate can later be replaced by server-side query parameters without redesigning the UI.

Do not present a local/static filter as exhaustive server search across clinics that were never loaded.

Recommended static-capable filter groups for the prototype:

- Specialty;
- Location / city from existing DTO data;
- Accepting requests from existing DTO data;
- Clinic type;
- Services;
- Sort: alphabetical / accepting first;
- Distance only if the current app already has real coordinates/location capability.

Do not invent a data-driven `Recommended` or `Top match` ranking.

## 14.5 Filter feedback

When filters are active:

- show a small active-state dot/count/badge on the filter control;
- allow quick reset from the sheet;
- empty state must explain that no clinics match current filters and offer Reset.

## 14.6 Clinic result cards

Each card should communicate enough value to make comparison easy.

Preferred hierarchy:

```text
[clinic image]
Clinic Name
Location
Accepting requests
Specialty chips / supported metadata
Optional short value/trust line IF backed by real data
>
```

Cards should not feel like advertisements, but they should feel curated.

Use photography when available.

If no image exists, use a refined clinic placeholder aligned with the design system—not a huge generic medical icon occupying most of the card.

## 14.7 No invented trust claims

Do not display strings such as:

- Top match
- Fast administrative review
- Best clinic
- Personalized support
- Highly recommended

unless those statements come from a real, approved backend/business rule.

The UI can create value through hierarchy and presentation without inventing claims.

---

# 15. Screen 3 — Clinic detail

## 15.1 Goal

The clinic detail page should make the patient feel that they are choosing a real, trustworthy healthcare destination.

It must answer:

1. What clinic is this?
2. Where is it?
3. What does it specialize in?
4. Is it accepting requests?
5. What should I know before choosing it?
6. What happens after I select it?

## 15.2 Hero gallery

The image area should be significantly taller than the current static implementation.

Requirements:

- large hero clinic photo;
- image carousel if multiple approved images exist;
- current image count such as `1 / 6`;
- tap image opens full-screen gallery/lightbox;
- swipe between images;
- close/back control;
- respect safe areas;
- use existing media API/contracts only;
- lazy load/appropriate caching;
- graceful placeholder/error state.

Do not force a giant hero when the clinic has no media. Use a carefully sized fallback instead.

## 15.3 Primary identity block

Directly after the hero:

```text
Clinic Name
Location
Accepting new requests
Specialty summary / clinic type if backed by data
```

Keep important trust/status information immediately visible.

## 15.4 Specialty section

Add a dedicated section:

```text
Specialties
[Cardiology] [Orthopedics] [Physiotherapy] ...
```

Use compact chips or a clean list.

Show only specialties provided by an approved backend contract.

If the current Clinic DTO does not expose specialties, the implementing agent must not hardcode them. Report a backend contract gap and omit/feature-gate the section until data exists.

## 15.5 About this clinic

Display the clinic's real `about`/description field where available.

Use readable paragraph typography.

If long:

- truncate intelligently;
- offer `Show more`;
- avoid a giant card around the entire paragraph.

This section is editorial content and should breathe.

## 15.6 Location and Google Maps

Add a location section with:

- human-readable address;
- city;
- map preview if real geocodable location exists;
- action such as `Open in Google Maps` / `Directions`.

Use the current Clinic DTO address/city when available and do not change the API.

For this UI phase:

- a static map-preview visual may be used as presentation scaffolding;
- if only an address exists, an external maps query/deep link may use that address without requiring backend changes;
- do not invent precise coordinates and then treat them as authoritative;
- do not embed API secrets.

The map block should be designed now even if the first implementation uses a static preview. It must be replaceable later by real coordinates/maps integration without restructuring the page.

## 15.7 Trust/value information

Trust should come from real evidence, not generic marketing claims.

Potential evidence if supported:

- accepting requests;
- verified address;
- specialties;
- service availability;
- existing approved clinic details;
- privacy/security explanation at OmniCare platform level;
- what happens next in the request process.

Avoid fake awards, ratings, badges, or performance claims.

## 15.8 What happens next

The detail page may include a compact patient-friendly sequence based on the actual current workflow:

```text
1. Send your request
2. The clinic reviews it
3. You receive the next step in OmniCare
```

Copy must remain consistent with actual Phase-3 behavior.

Do not promise an appointment or response time the backend/business has not committed to.

## 15.9 Sticky selection CTA

Use a sticky bottom action surface where it improves conversion and orientation.

Possible layout:

```text
Clinic name / location / status           [Select this clinic]
```

Keep it compact enough not to obscure content.

Primary CTA should be obvious and stable.

---

# 16. Screen 4 — Request details steps

Any request-details screens between clinic selection and confirmation should follow the same design language.

Principles:

- one decision per screen or one clear grouped form;
- progressive disclosure;
- short labels;
- controlled selections;
- no technical backend terminology;
- clear validation near the relevant input;
- preserve user input when navigating back according to existing state architecture;
- no fake success before backend response.

Do not redesign underlying request semantics in this UI project.

---

# 17. Screen 5 — Review and confirm

## 17.1 Goal

The confirmation screen must reduce anxiety and answer:

> Am I about to send the right request to the right clinic for the right person?

This should feel calm and high-confidence.

## 17.2 Page structure

Preferred structure:

```text
Review your request

[Clinic thumbnail]
Clinic Name
Location
Accepting requests

────────────────

Patient
Me / Family member                       Change

Request
Request type / situation                 Change

Availability / relevant input
...                                      Change

Clinic
...                                      Change

────────────────

What happens next
Short accurate explanation

Privacy / important policy link if relevant

[ Submit request ]
```

Use the actual fields collected by the current flow.

Do not add invented sections.

## 17.3 Preserve emotional value

The selected clinic should remain visually present on the confirmation screen through:

- thumbnail;
- clinic name;
- location;
- accepting status where relevant.

Do not reduce the clinic to a raw UUID or plain text record at confirmation.

## 17.4 Change actions

Each editable decision can have a restrained `Change`/`Edit` action.

Requirements:

- secondary visual weight;
- clear target;
- return to the appropriate step;
- preserve other valid selections where current state architecture supports it;
- avoid forcing the patient to restart the entire request.

## 17.5 Primary action

One dominant action only.

Preferred wording should reflect actual behavior:

- `Submit request`
- or existing approved equivalent.

Do not use ambiguous `Next` if this action actually sends the request.

If the action merely advances to another confirmation step, `Continue` may be used.

## 17.6 What happens next

Before final submission, provide a short accurate reassurance based on actual system behavior.

Example style:

> The clinic will review your request. If more information is needed, you'll receive a request in OmniCare. You'll see updates in your request status.

Do not promise acceptance, date/time, or response SLA unless currently guaranteed.

---

# 18. Screen 6 — Submission success / request created

If the current flow already has a success screen, redesign it consistently.

The success state should provide:

- clear confirmation that the request was sent;
- clinic identity;
- request reference only if useful to the patient;
- next-step explanation;
- one primary next action, such as `View request`;
- one quiet route back to home if appropriate.

Avoid giant success illustrations unless they add real value.

Do not display backend technical IDs as the main confirmation message.

---

# 19. Loading states

Use polished skeletons or restrained progress where appropriate.

Distinguish:

- first load;
- refreshing;
- pagination/load more;
- submission in progress.

Do not block the entire screen for ordinary refreshes if content can remain visible safely.

Primary actions must prevent accidental duplicate submission while the backend request is pending.

---

# 20. Empty states

Empty states must explain what happened and what the patient can do.

Examples:

### No clinic search results

> No clinics match your search.

Offer:

- clear search;
- reset filters.

### No family members

Do not invent family-member creation in this flow unless already supported. Use current profile/family architecture and provide the existing valid path.

---

# 21. Error states

Never display:

- raw ProblemDetail JSON;
- backend exception text;
- SQL errors;
- internal error codes as patient-facing copy;
- stack traces.

Use the existing application error mapping.

Errors should be:

- close to the failed action;
- clear;
- non-technical;
- retryable when appropriate;
- non-destructive to valid user input.

---

# 22. Accessibility

Accessibility is part of the design quality, not a later compliance task.

Required:

- minimum usable touch target sizes;
- semantic labels for icons;
- status never communicated by color alone;
- adequate contrast;
- text scaling support;
- layout must remain usable with larger text;
- bottom sheets accessible to screen readers;
- keyboard/focus behavior safe where relevant;
- dismissible sheets provide clear close semantics;
- image gallery exposes meaningful accessibility labels;
- primary actions remain reachable with system text scaling;
- reduced-motion preferences respected if animation is introduced.

---

# 23. Motion

Motion should communicate state, hierarchy, or navigation.

Allowed examples:

- bottom sheet entrance/dismissal;
- image gallery transition;
- selection state transition;
- subtle pressed states;
- short content transition after filter application.

Avoid:

- decorative looping animations;
- flashy gradient motion;
- long transitions that slow the user down.

---

# 24. Image treatment

Clinic imagery is a major value signal.

Requirements:

- high-quality aspect ratios;
- consistent crop behavior;
- rounded clipping where appropriate;
- loading placeholder;
- error fallback;
- avoid distortion;
- do not show low-resolution images stretched to hero dimensions;
- use existing media storage/API policy;
- no medical procedure imagery on the Clinic Request discovery screen unless explicitly product-approved.

The UI should feel trustworthy and welcoming, not graphic or clinical.

---

# 25. Content rules

Copy should be:

- concise;
- reassuring;
- accurate;
- patient-friendly;
- free of technical backend words.

Avoid:

- `ASSIGNED`
- `REQUEST_COORDINATION`
- `READY_FOR_PLANNING`
- raw enum strings
- role codes
- UUIDs
- database terminology

Those are operational/internal concepts and should not appear in the patient discovery/confirmation UI unless translated into a patient-meaningful state.

---

# 26. Trust architecture

The UI should build trust using **truthful evidence**.

Preferred trust sources:

- real clinic imagery;
- clear clinic identity;
- real location;
- accepting-request state;
- approved specialties;
- accurate process explanation;
- privacy/security language backed by OmniCare behavior;
- transparent confirmation summary;
- clear edit/change options.

Do not build trust using invented marketing claims.

---

# 27. Static-first presentation data rule

This UI redesign intentionally proceeds **without backend work**.

Patient-facing values fall into two groups:

### A. Real operational values — must stay real

These must continue to come from the current API/current application state:

- clinic identity and ID;
- clinic name;
- city/address where currently exposed;
- accepting-requests state;
- selected patient/family member;
- request type/situation;
- request submission state;
- any value that affects workflow, eligibility, security, or the submitted payload.

### B. Presentation enrichment — may be static temporarily

These may come from one centralized Flutter-only static metadata layer until backend support is added later:

- specialties;
- clinic type;
- services;
- gallery/demo images;
- descriptive clinic copy;
- map preview visual;
- non-authoritative filter tags.

The UI must merge A + B at presentation level only.

Do not put B into API DTOs, repository payloads, or request submission models.

Ratings, real user reviews, SLA/response-speed claims, availability promises, verification claims, and algorithmic ranking are **not allowed as fake static evidence**.

---

# 28. Performance requirements

The redesign must not make the app heavy.

Requirements:

- lazy lists for clinic results;
- bounded paging from backend;
- image thumbnails sized appropriately;
- hero/gallery images loaded on demand;
- avoid loading full gallery for every result card;
- avoid API-per-widget-build;
- do not refetch identical clinic data repeatedly during rebuilds;
- no unnecessary animation controllers;
- no new heavy UI packages unless absolutely required;
- reuse existing image/cache solution if present;
- maintain smooth scrolling.

---

# 29. Security and privacy requirements

The redesign must preserve existing privacy boundaries.

Do not:

- log request DTOs;
- log patient/family details;
- persist clinic/request details outside existing approved state architecture;
- expose medical data;
- expose MRS payloads;
- leak internal resource identifiers;
- embed API secrets in the app for Maps or media.

Google Maps/API configuration must follow existing secure environment/config patterns.

---

# 30. Reusable component direction

Create reusable components only when they represent real repeated product patterns.

Potential reusable patterns:

- `OcPatientTopBar`
- `OcSearchField`
- `OcFilterButton`
- `OcFilterSheet`
- `OcClinicCard`
- `OcClinicStatusChip`
- `OcSpecialtyChip`
- `OcClinicImageGallery`
- `OcClinicPresentationMetadata` / presentation mapper (conceptual; follow repo naming)
- `OcSectionHeader`
- `OcInfoRow`
- `OcReviewRow`
- `OcStickyPrimaryAction`
- `OcEmptyState`
- `OcErrorState`

Names are conceptual only. Follow repository naming conventions after inspection.

Do not create a component abstraction just because an element appears once.

---

# 31. Screen-to-screen consistency

The family selector, clinic list, clinic detail, request form, and review/confirmation screen must feel like the same application.

Consistency must cover:

- same typography scale;
- same page padding;
- same icon language;
- same CTA hierarchy;
- same surface treatment;
- same status chips;
- same back-navigation treatment;
- same bottom-sheet pattern;
- same loading/error patterns.

Do not redesign only the Clinic Detail page while leaving the rest visually unrelated.

---

# 32. Patient request flow visual hierarchy

The expected visual hierarchy across the full flow is:

```text
Decision
↓
Evidence/context
↓
Secondary detail
↓
Primary action
```

Example — Clinic Detail:

```text
Clinic image + identity
↓
Location / accepting status / specialties
↓
About / map / process detail
↓
Select this clinic
```

Example — Review:

```text
Review your request
↓
Clinic + patient + request summary
↓
What happens next
↓
Submit request
```

---

# 33. Anti-patterns to reject during implementation review

Reject implementations that introduce:

- giant title + paragraph taking most of first viewport;
- five different green shades fighting for attention;
- thick borders around every selected element;
- nested cards inside cards inside cards;
- generic medical cross icons replacing real clinic imagery when media exists;
- fake rating stars;
- fake "Top match" labels;
- fake "fast review" claims;
- raw specialty strings hardcoded into widgets;
- giant hero area with no image/value;
- raw Google Maps API key in source;
- bottom sheet that cannot dismiss by outside tap;
- filter screen as a full new route unless there is a strong product reason;
- filtering entirely in Flutter if backend owns pagination/filtering;
- separate full-page confirmation form duplicating all previous inputs;
- buttons with equal visual weight for primary and secondary actions;
- permanent destructive Logout icon on every transactional screen;
- raw internal IDs displayed to patient.

---

# 34. Implementation sequence

A coding model should implement in this order unless repository reality requires a narrower adjustment:

```text
UI foundation/tokens
    ↓
Shared patient shell/header/navigation cleanup
    ↓
Who needs care?
    ↓
Choose a clinic
    ↓
Filter bottom sheet
    ↓
Clinic card
    ↓
Clinic detail
    ↓
Gallery
    ↓
Specialties (real API data or isolated static presentation metadata)
    ↓
Map/location (current address + static preview/deep link as needed)
    ↓
Review and confirm
    ↓
Submission success
    ↓
Cross-flow polish/accessibility/performance
```

Do not redesign all screens simultaneously before establishing shared tokens/components.

---

# 35. Testing expectations

The redesign must preserve functional regression coverage and add UI-specific tests where meaningful.

At minimum verify:

### Who needs care

- self selection;
- family selection;
- selection state;
- continue availability;
- no duplicate/incorrect selection.

### Clinic list

- initial load;
- search;
- pagination;
- image fallback;
- empty state;
- open Clinic Detail;
- real API values remain authoritative;
- static presentation enrichment stays isolated from API/domain models.

### Filter sheet

- opens;
- outside tap dismisses;
- swipe/close behavior as applicable;
- apply;
- reset;
- active-filter indicator;
- supported current fields + approved static presentation filter metadata;
- empty filtered result.

### Clinic detail

- real data rendering;
- image gallery if media exists;
- image fallback;
- specialties render from real API data or isolated static presentation metadata;
- map/location block renders from current address plus approved static preview/deep-link behavior;
- accepting status;
- Select Clinic action.

### Review

- selected clinic remains visible;
- selected subject visible;
- request inputs summarized;
- Change routes correctly;
- submit guarded from double tap;
- backend success/failure handled safely.

### Accessibility

- semantics for icon-only controls;
- large-text basic layout;
- status text not color-only;
- bottom-sheet semantics;
- gallery close/back semantics.

---

# 36. Definition of done

This redesign is considered complete only when:

1. the Clinic Request flow still works end-to-end against current backend contracts;
2. no business workflow semantics were changed accidentally;
3. family-member selection is visually upgraded and remains functional;
4. Clinic List is compact, valuable, searchable, and filterable;
5. Filter uses a dismissible bottom sheet;
6. Clinic cards make good use of real imagery and real metadata;
7. Clinic Detail uses a larger interactive gallery when media exists;
8. Specialty section exists and uses real API data when available, otherwise isolated Flutter-only static presentation metadata;
9. location/map experience exists without backend modification, using current address data plus safe static preview/deep-link behavior until real map metadata is added later;
10. confirmation clearly summarizes patient + clinic + request;
11. clinic identity/value remains visible during confirmation;
12. edit/change actions preserve the user's journey;
13. one clear primary CTA exists at each decision step;
14. no fake ratings, SLA claims, availability promises, verification claims, or algorithmic recommendations exist; temporary static specialties/gallery/service metadata is isolated as presentation-only scaffolding;
15. typography, icons, spacing, radius, and colors are consistent;
16. accessibility requirements are respected;
17. performance does not regress materially;
18. no new privacy/security regression exists;
19. existing tests remain green;
20. new focused UI tests pass;
21. `flutter analyze` introduces no new errors/warnings attributable to this work;
22. release build validation remains green under available local tooling.

---

# 37. Final implementation philosophy

The coding model must treat the patient as a person making an important healthcare decision—not as a user completing a database form.

The interface should create value through:

```text
clarity
+ real clinic imagery
+ hierarchy
+ trustworthy evidence
+ concise information
+ progressive disclosure
+ calm confirmation
+ control
+ consistent feedback
```

The design should feel premium because it is **clear, intentional, truthful, and carefully crafted**.

Not because it is overloaded with decoration.

The target experience is:

> "I understand this clinic, I trust what I am seeing, I know what I am requesting, and I feel confident continuing."

That is the standard every screen in this flow must meet.


---

# 38. v1.1 implementation freeze summary

For any AI coding model consuming this skill, the most important execution rule is:

```text
REDESIGN THE FLUTTER PRESENTATION
PRESERVE THE CURRENT FUNCTIONAL FLOW
DO NOT TOUCH THE BACKEND
DO NOT CHANGE THE CURRENT FLUTTER API/NETWORK CONTRACTS
USE ISOLATED STATIC UI METADATA WHEN A VISUAL SECTION NEEDS DATA THAT DOES NOT EXIST YET
```

The purpose of this phase is to prove and polish the premium OmniCare patient experience first. Backend enrichment for specialties, richer maps, gallery metadata, services, and server-side filters can be designed and connected later without throwing away the UI architecture created now.
