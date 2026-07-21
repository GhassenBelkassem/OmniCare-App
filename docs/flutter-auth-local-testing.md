# Flutter Auth Local Testing

Run the patient app with an explicit backend base URL:

```bash
flutter run \
  --dart-define=OMNICARE_API_BASE_URL=http://10.0.2.2:8080
```

For local Chrome testing, keep the flags on the same command, either one line:

```bash
flutter run -d chrome --web-port=53472 --dart-define=OMNICARE_API_BASE_URL=http://localhost:8080
```

or with trailing backslashes:

```bash
flutter run -d chrome \
  --web-port=53472 \
  --dart-define=OMNICARE_API_BASE_URL=http://localhost:8080
```

Use these local development URLs:

- Chrome/web: `http://localhost:8080`
- Android emulator: `http://10.0.2.2:8080`
- iOS simulator: `http://localhost:8080`
- Physical device: `http://<LAN_IP>:8080`

The Spring Boot backend must bind to an address reachable by the device or
emulator. Physical devices require the machine LAN IP through
`OMNICARE_API_BASE_URL`; `localhost` points at the device itself.

Phone login and signup use real backend OTP delivery. Do not hardcode an OTP in
Flutter. Do not print OTPs, access tokens, refresh tokens, passwords, or full
Auth response bodies.

Safe status checks:

- Confirm the app reaches the OTP screen after a neutral initiate response.
- Confirm successful verification routes to onboarding when the profile says
  `onboardingCompleted: false`.
- Confirm successful verification routes home when the profile says
  `onboardingCompleted: true`.
- Confirm logout clears local state even if the backend request fails.

Android debug builds allow cleartext traffic for local development in
`android/app/src/debug/AndroidManifest.xml`. Release transport security is not
weakened by that debug manifest.

iOS release transport security is not weakened in `ios/Runner/Info.plist`.
The iOS simulator should use `http://localhost:8080` with a locally running
backend. If a debug simulator build is blocked by App Transport Security in a
local environment, add a debug-only Xcode build configuration exception for the
local host instead of adding unrestricted `NSAllowsArbitraryLoads=true` to the
production plist.

For a physical device, use the Mac LAN IP in `OMNICARE_API_BASE_URL`, make
Spring Boot listen on an interface reachable from the network, keep the phone
and Mac on the same network, and allow the backend port through the firewall.
