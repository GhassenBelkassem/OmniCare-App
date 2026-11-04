FROM ghcr.io/cirruslabs/flutter:3.41.4 AS build

USER root
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG OMNICARE_API_BASE_URL
ARG GOOGLE_MAPS_API_KEY=""

RUN test -n "${OMNICARE_API_BASE_URL}" || \
    (echo "OMNICARE_API_BASE_URL is required for a hosted Flutter Web build" >&2; exit 1)

RUN flutter build web --release \
    --dart-define=OMNICARE_API_BASE_URL="${OMNICARE_API_BASE_URL}" \
    --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY}"

FROM caddy:2-alpine

COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=build /app/build/web /srv

EXPOSE 8080

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
