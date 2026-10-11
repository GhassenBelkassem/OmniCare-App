import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/request_core/application/request_submission_controller.dart';
import 'package:omnicare_mobile/features/request_core/data/request_repository.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_core/identity/in_flight_request_store.dart';
import 'package:omnicare_mobile/features/request_core/identity/request_operation_id.dart';
import 'package:omnicare_mobile/features/request_flow/screens/request_flow_entry_screen.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';

class _FakeRequestRepository implements RequestRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFamilyRepository implements FamilyRepository {
  @override
  Future<List<FamilyMember>> getFamilyMembers() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureBackend implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

class _CountingOperationIdFactory extends RequestOperationIdFactory {
  int issued = 0;

  @override
  RequestOperationId next() {
    issued++;
    final suffix = issued.toRadixString(16).padLeft(12, '0');
    return RequestOperationId.parse('00000000-0000-4000-8000-$suffix');
  }
}

Widget _buildHarness({
  required RequestSubmissionController request,
  required FamilyProvider family,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<RequestSubmissionController>.value(value: request),
      ChangeNotifierProvider<FamilyProvider>.value(value: family),
    ],
    child: MaterialApp(
      home: Consumer<RequestSubmissionController>(
        builder: (context, request, child) => const RequestFlowEntryScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'initializes after mount exactly once and preserves reset semantics',
    (tester) async {
      final operationIds = _CountingOperationIdFactory();
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
        inFlightStore: InFlightRequestStore(backend: _FakeSecureBackend()),
        operationIdFactory: operationIds,
      );
      final family = FamilyProvider(repository: _FakeFamilyRepository());
      addTearDown(request.dispose);
      addTearDown(family.dispose);

      await request.beginNewRequest();
      request.selectClinic('old-clinic');
      request.selectFamilyMemberSubject(
        FamilyMember(
          id: 'old-member',
          accountHolderId: 'account-holder',
          firstName: 'Old',
          lastName: 'Subject',
          dateOfBirth: DateTime(1990),
          gender: 'F',
          relationship: 'parent',
          graduated: false,
        ),
      );
      request.selectSituation(RequestSituation.appointment);
      final previousOperationId = request.operationId;

      var notifications = 0;
      request.addListener(() => notifications++);

      await tester.pumpWidget(_buildHarness(request: request, family: family));

      expect(tester.takeException(), isNull);
      expect(operationIds.issued, 2);
      expect(notifications, 1);
      expect(request.operationId, isNot(previousOperationId));
      expect(request.status, RequestSubmissionStatus.draft);
      expect(request.subject.isSelf, isTrue);
      expect(request.selectedClinicId, isNull);
      expect(request.selectedSituation, isNull);
      expect(request.selectedPickup, isNull);
      expect(find.text('Who needs care?'), findsOneWidget);

      await tester.pumpWidget(_buildHarness(request: request, family: family));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(operationIds.issued, 2);
      expect(notifications, 1);
    },
  );
}
