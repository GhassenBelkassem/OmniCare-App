import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';

void main() {
  test('primary button themes use white content on action green', () {
    final style = buildOmniPrimaryButtonStyle();

    expect(
      style.backgroundColor!.resolve(const <WidgetState>{}),
      OmniColors.primaryAction,
    );
    expect(style.foregroundColor!.resolve(const <WidgetState>{}), Colors.white);
    expect(
      style.backgroundColor!.resolve(const {WidgetState.pressed}),
      OmniColors.primaryActionPressed,
    );
    expect(
      style.foregroundColor!.resolve(const {WidgetState.pressed}),
      Colors.white,
    );
  });

  test('disabled primary buttons remain visibly disabled', () {
    final style = buildOmniPrimaryButtonStyle();
    final disabled = const {WidgetState.disabled};

    expect(style.backgroundColor!.resolve(disabled), OmniColors.borderLight);
    expect(style.foregroundColor!.resolve(disabled), OmniColors.textTertiary);
  });
}
