# OmniCare mobile and web application

## Railway Flutter Web deployment

Railway deploys the web target from the repository `Dockerfile`. Configure the
following service variable before deploying:

```text
OMNICARE_API_BASE_URL=https://omnicare-backend-dev.up.railway.app
```

Google Maps is optional. When enabled, provide a browser-restricted key:

```text
GOOGLE_MAPS_API_KEY=replace_with_restricted_web_key
```

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
