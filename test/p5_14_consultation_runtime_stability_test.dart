import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/clinical_order/clinical_order_card.dart';
import 'package:omnicare_mobile/features/doctor/consultation_detail_screen.dart';
import 'package:provider/provider.dart';

const _consultationId = 'e97c7a54-e378-4d59-b656-5e15457cdc02';

void main() {
  for (final size in <Size>[const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'canonical Consultation remains scrollable through editors at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final adapter = _ConsultationAdapter();
        final client = _client(adapter);
        addTearDown(() => client.close(force: true));

        await tester.pumpWidget(
          Provider<AppHttpClient>.value(
            value: client,
            child: MaterialApp(
              theme: buildOmniTheme(),
              home: const ConsultationDetailScreen(
                consultationId: _consultationId,
                activeWorkspace: true,
                consultation: <String, dynamic>{
                  'id': _consultationId,
                  'sourceId': '8eca2732-a477-4b3a-af89-8982afcae325',
                  'status': 'IN_PROGRESS',
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final root = find.byKey(const ValueKey('consultation-detail-scroll'));
        expect(root, findsOneWidget);
        final scroll = tester.widget<SingleChildScrollView>(root).controller!;
        expect(scroll.hasClients, isTrue);
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        final baselineBarriers = find.byType(ModalBarrier).evaluate().length;

        scroll.jumpTo(120);
        await tester.pump();
        final clinicalField = find.byType(TextFormField).first;
        await tester.showKeyboard(clinicalField);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final beforeKeyboardDrag = scroll.offset;
        await tester.drag(root, const Offset(0, -260));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(beforeKeyboardDrag));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        FocusManager.instance.primaryFocus?.unfocus();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Add medication'));
        await tester.tap(find.text('Add medication'));
        await tester.pumpAndSettle();
        expect(find.text('Medication 1'), findsOneWidget);
        expect(find.byType(ModalBarrier).evaluate().length, baselineBarriers);
        final afterMedicationOpen = scroll.offset;
        await tester.drag(root, const Offset(0, -220));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThanOrEqualTo(afterMedicationOpen));
        final prescriptionSave = find.widgetWithText(OutlinedButton, 'Save');
        await tester.ensureVisible(prescriptionSave);
        await tester.tap(prescriptionSave);
        await tester.pumpAndSettle();
        expect(adapter.prescriptionWrites, 1);
        expect(find.byType(ModalBarrier).evaluate().length, baselineBarriers);

        await tester.ensureVisible(
          find.widgetWithText(OutlinedButton, 'Laboratory'),
        );
        await tester.tap(find.widgetWithText(OutlinedButton, 'Laboratory'));
        await tester.pumpAndSettle();
        expect(find.text('Requested examination'), findsOneWidget);
        final orderField = find.descendant(
          of: find.byType(ClinicalOrderCard),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(orderField, 'Synthetic laboratory order');
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Requested examination'), findsNothing);
        expect(find.byType(ModalBarrier).evaluate().length, baselineBarriers);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Laboratory'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(ClinicalOrderCard),
            matching: find.byType(TextFormField),
          ),
          'Synthetic laboratory order',
        );
        await tester.pump();
        final orderSave = find.descendant(
          of: find.byType(ClinicalOrderCard),
          matching: find.widgetWithText(ElevatedButton, 'Save'),
        );
        await tester.ensureVisible(orderSave);
        final orderSaveButton = tester.widget<ElevatedButton>(orderSave);
        expect(orderSaveButton.onPressed, isNotNull);
        orderSaveButton.onPressed!.call();
        await tester.pumpAndSettle();
        expect(adapter.orderCreates, 1);
        expect(find.text('Synthetic laboratory order'), findsOneWidget);
        expect(find.byType(ModalBarrier).evaluate().length, baselineBarriers);

        for (final label in <String>['Imaging', 'Referral']) {
          final button = find.widgetWithText(OutlinedButton, label);
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
          await tester.pumpAndSettle();
          expect(find.byType(ModalBarrier).evaluate().length, baselineBarriers);
        }

        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(find.text('Official artifacts'), findsOneWidget);
        expect(find.text('Finish consultation'), findsWidgets);

        final retainedOffset = scroll.offset / 2;
        scroll.jumpTo(retainedOffset);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(scroll.hasClients, isTrue);
        expect(scroll.offset, closeTo(retainedOffset, 1));
        await tester.drag(root, const Offset(0, 260));
        await tester.pumpAndSettle();
        expect(scroll.offset, lessThan(retainedOffset));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

AppHttpClient _client(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryStorage()),
    baseUrl: 'https://api.test',
    dio: dio,
    refreshDio: Dio()..httpClientAdapter = _ConsultationAdapter(),
  );
}

class _ConsultationAdapter implements HttpClientAdapter {
  int prescriptionWrites = 0;
  int orderCreates = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    Object body;
    var status = 200;
    if (path.endsWith('/clinical-record')) {
      body = _clinicalRecord();
    } else if (path.endsWith('/prescription')) {
      if (options.method == 'PUT') prescriptionWrites++;
      final request = options.data is Map
          ? (options.data as Map).cast<String, dynamic>()
          : const <String, dynamic>{};
      body = _prescription(
        version: options.method == 'PUT' ? 2 : 1,
        content: request['prescription'] as Map?,
      );
    } else if (path.endsWith('/clinical-orders')) {
      if (options.method == 'POST') {
        orderCreates++;
        status = 201;
        body = _order(options.data as Map);
      } else {
        body = const <String, Object>{'orders': <Object>[]};
      }
    } else if (path.endsWith('/artifacts')) {
      body = const <String, Object>{'artifacts': <Object>[]};
    } else if (path.endsWith('/$_consultationId')) {
      body = const <String, Object>{
        'consultationId': _consultationId,
        'status': 'IN_PROGRESS',
        'medicalAccessStatus': 'ACTIVE',
        'version': 1,
      };
    } else {
      status = 404;
      body = const <String, Object>{'errorCode': 'NOT_FOUND'};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: const <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  Map<String, Object?> _clinicalRecord() => <String, Object?>{
    'clinicalRecordVersion': 0,
    'schemaVersion': 2,
    'clinicalRecord': <String, Object?>{
      'chiefComplaint': null,
      'history': const <String, Object?>{},
      'clinicalFindings': const <Object>[],
      'diagnoses': const <Object>[],
      'assessment': null,
      'treatmentPlan': const <Object>[],
      'followUp': const <String, Object?>{'required': false},
      'notes': null,
      'medicationDecision': 'MEDICATION_PRESCRIBED',
    },
  };

  Map<String, Object?> _prescription({required int version, Map? content}) =>
      <String, Object?>{
        'prescriptionId': '11111111-1111-4111-8111-111111111111',
        'prescriptionVersion': version,
        'clinicalRecordVersion': 0,
        'schemaVersion': 2,
        'status': 'DRAFT',
        'finalized': false,
        'medicationDecision': 'MEDICATION_PRESCRIBED',
        'signedAt': null,
        'signatureAlgorithm': null,
        'prescription':
            content ??
            const <String, Object?>{
              'medications': <Object>[],
              'generalInstructions': null,
            },
      };

  Map<String, Object?> _order(Map request) {
    final data = request.cast<String, dynamic>();
    return <String, Object?>{
      'clinicalOrderId': '22222222-2222-4222-8222-222222222222',
      'consultationId': _consultationId,
      'category': data['category'],
      'status': 'DRAFT',
      'clinicalOrderVersion': 1,
      'schemaVersion': 1,
      'definition': data['definition'],
    };
  }
}

class _MemoryStorage implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}
