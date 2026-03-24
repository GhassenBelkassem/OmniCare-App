@JS()
library;

import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:js/js.dart';

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
}

class GoogleWebSignInButton extends StatefulWidget {
  final void Function(String idToken) onIdToken;

  const GoogleWebSignInButton({super.key, required this.onIdToken});

  @override
  State<GoogleWebSignInButton> createState() => _GoogleWebSignInButtonState();
}

class _GoogleWebSignInButtonState extends State<GoogleWebSignInButton> {
  late final String _viewType;
  html.DivElement? _container;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'google-signin-button-${DateTime.now().microsecondsSinceEpoch}';

    // ignore:undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      _container = html.DivElement();
      return _container!;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _initGis());
  }

  String? _readClientIdFromMeta() {
    final tag = html.document.querySelector(
      'meta[name="google-signin-client_id"]',
    );
    return tag?.getAttribute('content');
  }

  void _initGis() {
    if (!mounted || _initialized) return;

    final clientId = _readClientIdFromMeta();
    if (clientId == null || clientId.isEmpty) {
      throw StateError('Missing google-signin-client_id meta tag');
    }

    final container = _container;
    if (container == null) return;

    _googleAccountsId.initialize(
      _IdConfiguration(
        client_id: clientId,
        callback: allowInterop((dynamic response) {
          final credential = (response is Object)
              ? (response as dynamic).credential
              : null;
          final token = credential?.toString();
          if (token != null && token.isNotEmpty) {
            widget.onIdToken(token);
          }
        }),
      ),
    );

    _googleAccountsId.renderButton(container, {
      'type': 'standard',
      'theme': 'outline',
      'size': 'large',
      'width': 384,
      'text': 'continue_with',
      'shape': 'pill',
    });

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
