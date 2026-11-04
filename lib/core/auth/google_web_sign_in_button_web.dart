// Google Identity Services still exposes this button through browser DOM and
// snake_case JavaScript fields; keep the interop isolated in this web file.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, non_constant_identifier_names

@JS()
library;

import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:js/js.dart';

import '../theme/omni_theme.dart';

@JS('google.accounts.id')
external _GoogleAccountsId get _googleAccountsId;

@JS()
@anonymous
class _IdConfiguration {
  external String get client_id;
  external Function get callback;
  external factory _IdConfiguration({
    required String client_id,
    required Function callback,
  });
}

@JS()
class _GoogleAccountsId {
  external void initialize(_IdConfiguration configuration);
  external void renderButton(html.Element parent, dynamic options);
  external void disableAutoSelect();
}

typedef _GoogleIdTokenCallback = void Function(String idToken);

/// Owns the one process-wide GIS initialization for the current Dart isolate.
/// Individual button widgets only register callbacks and render DOM buttons.
final _GoogleWebIdentityCoordinator _googleWebIdentityCoordinator =
    _GoogleWebIdentityCoordinator();

class _GoogleWebIdentityCoordinator {
  final Map<Object, _GoogleIdTokenCallback> _callbacks = {};
  bool _initialized = false;
  String? _clientId;

  Object register(_GoogleIdTokenCallback callback) {
    final registration = Object();
    _callbacks[registration] = callback;
    return registration;
  }

  void update(Object registration, _GoogleIdTokenCallback callback) {
    if (_callbacks.containsKey(registration)) {
      _callbacks[registration] = callback;
    }
  }

  void unregister(Object registration) {
    _callbacks.remove(registration);
  }

  void ensureInitialized(String clientId) {
    if (_initialized) {
      if (_clientId != clientId) {
        throw StateError('Google Sign-In client ID changed at runtime.');
      }
      return;
    }

    _googleAccountsId.initialize(
      _IdConfiguration(
        client_id: clientId,
        // ignore: undefined_method
        callback: allowInterop((dynamic response) {
          final credential = (response is Object)
              ? (response as dynamic).credential
              : null;
          final token = credential?.toString();
          if (token == null || token.isEmpty || _callbacks.isEmpty) return;
          _callbacks.values.last(token);
        }),
      ),
    );
    _clientId = clientId;
    _initialized = true;
  }
}

void clearGoogleWebProviderSession() {
  _googleAccountsId.disableAutoSelect();
}

class GoogleWebSignInButton extends StatefulWidget {
  final void Function(String idToken) onIdToken;

  const GoogleWebSignInButton({super.key, required this.onIdToken});

  @override
  State<GoogleWebSignInButton> createState() => _GoogleWebSignInButtonState();
}

class _GoogleWebSignInButtonState extends State<GoogleWebSignInButton> {
  late final String _viewType;
  late final Object _callbackRegistration;
  html.DivElement? _container;
  int? _renderedWidth;

  @override
  void initState() {
    super.initState();
    _callbackRegistration = _googleWebIdentityCoordinator.register(
      widget.onIdToken,
    );
    _viewType = 'google-signin-button-${DateTime.now().microsecondsSinceEpoch}';

    // ignore:undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      _container = html.DivElement()
        ..style.width = '100%'
        ..style.height = '50px';
      return _container!;
    });
  }

  @override
  void didUpdateWidget(covariant GoogleWebSignInButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _googleWebIdentityCoordinator.update(
      _callbackRegistration,
      widget.onIdToken,
    );
  }

  @override
  void dispose() {
    _googleWebIdentityCoordinator.unregister(_callbackRegistration);
    _container = null;
    super.dispose();
  }

  String? _readClientIdFromMeta() {
    final tag = html.document.querySelector(
      'meta[name="google-signin-client_id"]',
    );
    return tag?.getAttribute('content');
  }

  void _initGis(int width) {
    if (!mounted) return;

    final clientId = _readClientIdFromMeta();
    if (clientId == null || clientId.isEmpty) {
      throw StateError('Missing google-signin-client_id meta tag');
    }

    final container = _container;
    if (container == null) return;

    _googleWebIdentityCoordinator.ensureInitialized(clientId);

    if (_renderedWidth == width) return;
    container.children.clear();

    _googleAccountsId.renderButton(container, {
      'type': 'standard',
      'theme': 'outline',
      'size': 'large',
      'width': width,
      'text': 'continue_with',
      'shape': 'rectangular',
      'logo_alignment': 'left',
    });

    _renderedWidth = width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(200.0, 400.0).round();
        WidgetsBinding.instance.addPostFrameCallback((_) => _initGis(width));

        return SizedBox(
          height: 50,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: OmniColors.surfacePrimary,
              borderRadius: BorderRadius.circular(OmniRadii.field),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(OmniRadii.field),
              child: HtmlElementView(viewType: _viewType),
            ),
          ),
        );
      },
    );
  }
}
