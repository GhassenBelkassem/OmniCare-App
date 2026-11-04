# OmniCare static browser demo

The demo is a separate Flutter entrypoint. It reuses the production widgets,
routes, theme, and models, but it cannot contact the OmniCare backend.

## Run

```bash
flutter run -d chrome -t lib/main_demo.dart
```

The demo starts in the patient workspace. Use the **DÉMO STATIQUE** menu in the
top-right corner to switch between Patient, Doctor, Clinic, and the public
authentication screens.

The authentication screen also accepts any password with these addresses:

- `patient@demo.omnicare.tn`
- `doctor@demo.omnicare.tn`
- `clinic@demo.omnicare.tn`

## Build

```bash
flutter build web -t lib/main_demo.dart --release
```

## Isolation contract

- `lib/main.dart` remains the backend-connected production entrypoint.
- `lib/main_demo.dart` never initializes Firebase, push notifications, or the
  realtime transport.
- `DemoHttpAdapter` is the only HTTP transport used by the demo. It resolves
  registered fixtures in memory and returns `DEMO_FIXTURE_MISSING` for every
  unregistered request. It never falls back to a socket transport.
- Demo authentication and token storage are memory-only and reset on refresh.

When a production screen adds a new API request, add its static response to
`lib/demo/demo_http_adapter.dart`. Missing fixtures are intentionally visible so
the demo cannot silently start using the backend.
