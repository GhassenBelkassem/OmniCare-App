import 'dart:js_interop';

@JS('google.maps')
external JSObject? get _googleMaps;

bool get isGoogleMapsJavaScriptLoaded => _googleMaps != null;
