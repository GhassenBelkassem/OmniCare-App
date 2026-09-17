---
name: omnicare-flutter-ui
description: Project authority for designing and implementing polished, modern OmniCare Flutter mobile UI. Use for screen creation, redesign, UX flows, navigation, forms, search, filters, bottom sheets, cards, animations, responsive behavior, accessibility, and visual polish. Preserve the existing OmniCare brand, typography, tokens, and reusable Flutter components.
compatibility: opencode
metadata:
  project: omnicare
  platform: flutter
---

# OmniCare Flutter UI

## Authority

This is the project-specific authority for OmniCare Flutter UI.

When another design or frontend skill conflicts with this skill, follow this skill.

Supporting skills provide inspiration and specialist knowledge. They do not override OmniCare project conventions.

## Existing design system

OmniCare already has its own:

- typography
- colors
- spacing conventions
- components
- assets
- visual identity

Inspect the repository before introducing new visual primitives.

Reuse existing theme values and shared widgets whenever they are appropriate.

Do not replace the existing typography, brand palette, or design system unless explicitly requested.

Do not create a second competing design system.

## Quality target

Aim for the product-design maturity of leading mobile applications without copying their visual identity.

Learn from:

### Airbnb

- strong search and discovery UX
- excellent filtering
- clear information hierarchy
- progressive disclosure
- polished cards
- useful bottom sheets
- clean detail screens
- obvious contextual actions

### Apple

- restraint
- clarity
- content-first design
- excellent spacing
- predictable navigation
- accessible interactions
- purposeful feedback
- subtle motion
- strong hierarchy

### Revolut

- high information density without clutter
- compact actions
- excellent state communication
- polished transactional flows

### Uber

- obvious primary action
- low cognitive load
- one-handed usability
- contextual controls
- real-time state communication

Use these products as quality references, never as templates to reproduce.

## Healthcare UX

OmniCare is a healthcare application.

Prioritize:

1. clarity
2. trust
3. speed
4. accessibility
5. hierarchy
6. predictability
7. error prevention
8. visual polish

For medical, urgent, clinical, consent, payment, or safety-relevant workflows:

clarity > novelty

predictability > experimentation

information hierarchy > decoration

Do not sacrifice comprehension for aesthetics.

## Design before implementation

For meaningful UI work, do not immediately start writing widgets.

First:

1. inspect the existing screen and surrounding flow
2. identify the user's actual goal
3. identify the primary action
4. identify primary, secondary, and supporting information
5. critique the existing hierarchy
6. identify unnecessary friction
7. determine what should be immediately visible
8. determine what can be progressively disclosed
9. decide the interaction model
10. then implement

Existing UI is not automatically a correct design specification.

Preserve functional behavior and good project conventions.

Poor hierarchy, layout, composition, spacing, or interaction design may be redesigned.

## Flutter only

The application is Flutter.

Flutter implementation rules override web-specific instructions from supporting skills.

Ignore implementation guidance involving:

- React
- React Native
- HTML
- CSS
- Tailwind
- shadcn
- Lucide React
- Recharts
- Framer Motion
- web DOM APIs

Never introduce web libraries to implement Flutter UI.

Translate useful design principles into idiomatic Flutter.

## Composition

Prefer:

- small reusable widgets
- semantic components
- clear widget responsibility
- const constructors where appropriate
- existing theme tokens
- existing shared components
- constraint-driven layouts
- lazy builders for dynamic lists
- clear visual hierarchy

Avoid:

- giant build methods
- deeply nested anonymous widget trees
- arbitrary magic numbers
- unnecessary Container widgets
- unnecessary Stack-based positioning
- duplicated UI primitives
- hardcoded colors when tokens exist
- hardcoded typography when styles exist

## Visual restraint

Do not make every section a card.

Do not use gradients simply to make a screen look modern.

Avoid unnecessary:

- glassmorphism
- shadows
- pills
- floating elements
- decorative badges
- oversized headings
- excessive whitespace
- excessive animations

Use visual emphasis where hierarchy requires it.

Modern does not mean decorative.

## Mobile ergonomics

Design for touch first.

Common actions should be comfortably reachable.

Use appropriate touch targets.

Avoid forcing repeated top-of-screen interaction for high-frequency actions.

Use bottom sheets when they genuinely improve contextual mobile interaction.

Do not use a bottom sheet merely because it looks modern.

## Responsive Flutter UI

Design from available constraints, not from a single reference device.

Consider:

- small phones
- large phones
- landscape where applicable
- tablets where applicable
- keyboard-visible states
- text scaling
- long localized text
- RTL layouts

Prefer constraint-based adaptation.

## States

Every meaningful asynchronous or data-driven UI must consider:

- initial state
- loading
- loaded
- empty
- error
- disabled
- retry
- partial data where relevant

Do not design only the happy path.

## Forms

Forms should minimize cognitive load.

Prefer:

- clear labels
- sensible defaults
- contextual validation
- appropriate input types
- visible progress for multi-step flows
- useful error recovery
- preserving entered data after recoverable errors

Do not expose backend terminology to patients.

## UX copy

Use direct user-facing language.

Buttons should describe their action.

Prefer:

- Save changes
- Continue
- Choose clinic
- Request appointment

over vague labels such as:

- Submit
- Confirm action
- Process

Keep terminology consistent throughout a flow.

Errors must explain:

1. what happened
2. what the user can do next

Empty states should guide users toward a useful next action.

## Motion

Motion should communicate:

- state change
- hierarchy
- continuity
- feedback

Prefer restrained micro-interactions.

Avoid animation whose only purpose is decoration.

Do not make every element animate on appearance.

Respect reduced-motion accessibility requirements.

## Accessibility

Treat accessibility as part of implementation quality.

Consider:

- semantic labels
- touch target sizes
- focus order
- text scaling
- contrast
- screen readers
- reduced motion
- RTL
- meaningful error messaging

## Visual quality gate

A UI task is not complete merely because:

- Dart compiles
- flutter analyze passes
- tests pass

Also review:

- hierarchy
- alignment
- spacing rhythm
- visual balance
- density
- discoverability
- primary-action prominence
- typography consistency
- component consistency
- loading state
- empty state
- error state
- disabled state
- keyboard behavior
- small-screen behavior
- long-content behavior
- accessibility

If screenshot or simulator inspection is available, inspect the rendered UI before declaring visual work complete.

Do not claim a screen looks polished based only on source code.

## Final principle

The goal is not to make OmniCare look like another application.

The goal is to give OmniCare the same level of design discipline, interaction quality, usability, and polish expected from the best modern mobile products.
