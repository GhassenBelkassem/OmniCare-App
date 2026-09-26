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
  bool _gisInitialized = false;
  int? _renderedWidth;

  @override
  void initState() {
    super.initState();
    _viewType = 'google-signin-button-${DateTime.now().microsecondsSinceEpoch}';

    // ignore:undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      _container = html.DivElement()
        ..style.width = '100%'
        ..style.height = '50px';
      return _container!;
    });
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

    if (!_gisInitialized) {
      _googleAccountsId.initialize(
        _IdConfiguration(
          client_id: clientId,
          // ignore: undefined_method
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
      _gisInitialized = true;
    }

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
