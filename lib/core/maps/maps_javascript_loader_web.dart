import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('google.maps')
external JSObject? get _googleMaps;

@JS('__omnicareGoogleMapsAuthFailed')
external bool? get _authenticationFailed;

Future<bool>? _loadFuture;

Future<bool> loadGoogleMapsJavaScript(String apiKey) =>
    _loadFuture ??= _load(apiKey);

Future<bool> _load(String apiKey) async {
  if (_authenticationFailed == true) return false;
  if (_googleMaps != null) return true;

  final completer = Completer<bool>();
  Timer? timeout;
  Timer? readinessPoll;
  StreamSubscription<web.Event>? loadSubscription;
  StreamSubscription<web.Event>? errorSubscription;

  void complete(bool value) {
    if (completer.isCompleted) return;
    timeout?.cancel();
    readinessPoll?.cancel();
    unawaited(loadSubscription?.cancel());
    unawaited(errorSubscription?.cancel());
    completer.complete(value);
  }

  final authFailureListener = ((web.Event _) => complete(false)).toJS;
  web.window.addEventListener(
    'omnicare-google-maps-auth-failure',
    authFailureListener,
  );

  final existing = web.document.querySelector(
    'script[data-omnicare-google-maps]',
  );
  // This selector is owned by this loader and is only ever assigned to a
  // script element below.
  // ignore: invalid_runtime_check_with_js_interop_types
  final script = existing is web.HTMLScriptElement
      ? existing
      : (web.document.createElement('script') as web.HTMLScriptElement);

  loadSubscription = script.onLoad.listen((_) {
    readinessPoll ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_authenticationFailed == true) {
        complete(false);
      } else if (_googleMaps != null) {
        Timer(const Duration(milliseconds: 500), () {
          complete(_authenticationFailed != true && _googleMaps != null);
        });
      }
    });
  });
  errorSubscription = script.onError.listen((_) => complete(false));
  timeout = Timer(const Duration(seconds: 8), () => complete(false));

  if (existing == null) {
    script
      ..setAttribute('data-omnicare-google-maps', 'true')
      ..async = true
      ..defer = true
      ..referrerPolicy = 'strict-origin-when-cross-origin'
      ..src = Uri.https('maps.googleapis.com', '/maps/api/js', {
        'key': apiKey,
        'loading': 'async',
        'auth_referrer_policy': 'origin',
      }).toString();
    web.document.head?.append(script);
  } else {
    readinessPoll = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_authenticationFailed == true) {
        complete(false);
      } else if (_googleMaps != null) {
        complete(true);
      }
    });
  }

  final result = await completer.future;
  web.window.removeEventListener(
    'omnicare-google-maps-auth-failure',
    authFailureListener,
  );
  return result;
}
