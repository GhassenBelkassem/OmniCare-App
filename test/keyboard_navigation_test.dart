import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/nav/keyboard_navigation.dart';

void main() {
  testWidgets('navigation waits for the keyboard inset to close', (
    tester,
  ) async {
    final bottomInset = ValueNotifier<double>(420);
    var navigationReady = false;
    addTearDown(bottomInset.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<double>(
          valueListenable: bottomInset,
          builder: (context, inset, _) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewInsets: EdgeInsets.only(bottom: inset)),
              child: Builder(
                builder: (context) => FilledButton(
                  onPressed: () async {
                    await dismissKeyboardBeforeNavigation(context);
                    navigationReady = true;
                  },
                  child: const Text('Continue'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(navigationReady, isFalse);

    bottomInset.value = 0;
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();

    expect(navigationReady, isTrue);
  });
}
