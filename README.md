# OmniCare mobile and web application

## Railway Flutter Web deployment

Railway deploys the web target from the repository `Dockerfile`. Configure the
following service variable before deploying:

```text
OMNICARE_API_BASE_URL=https://omnicare-backend-dev.up.railway.app
```

Google Maps is optional. When enabled, provide a browser-restricted key:

```text
GOOGLE_MAPS_WEB_API_KEY=replace_with_restricted_dev_web_key
```

This value is consumed at Flutter Web build time and is intentionally visible
to browsers. Restrict it to the Maps JavaScript API and the exact DEV HTTPS
origins. It must be different from the backend's server-side Google Routes key.

Leave Railway's custom build and start commands empty. The Docker image builds
Flutter Web and starts Caddy on Railway's injected `PORT`. Configure the
Railway health-check path as `/health`.

After Railway assigns the Flutter Web domain, add that exact HTTPS origin to
the backend's `CORS_ALLOWED_ORIGINS` and `WEBSOCKET_ALLOWED_ORIGINS` lists.

For native development against the hosted backend:

```bash
flutter run \
  --dart-define=OMNICARE_API_BASE_URL=https://omnicare-backend-dev.up.railway.app
```

For local Web Maps development, copy
`config/maps.web.local.example.json` to the Git-ignored
`config/maps.web.local.json`, set the restricted DEV Web key, and run:

```bash
flutter run -d chrome \
  --dart-define-from-file=config/maps.web.local.json
```

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
