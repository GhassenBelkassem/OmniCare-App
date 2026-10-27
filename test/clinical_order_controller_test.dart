import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/doctor/clinical_order/clinical_order.dart';
import 'package:omnicare_mobile/features/doctor/clinical_order/clinical_order_api.dart';
import 'package:omnicare_mobile/features/doctor/clinical_order/clinical_order_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_event.dart';

const consultationId = '11111111-1111-4111-8111-111111111111';

void main() {
  test('creates every V1 category and edits the same server order', () async {
    final api = _FakeClinicalOrderApi();
    for (final category in ClinicalOrderCategory.values) {
      final controller = ClinicalOrderController(
        consultationId: consultationId,
        api: api,
      );
      await controller.load();
      controller.beginCreate(category);
      controller.updateValue('${category.label} request');
      await controller.save();
      expect(controller.orders.last.category, category);
      expect(controller.orders.last.version, 1);
      controller.dispose();
    }
    final controller = ClinicalOrderController(
      consultationId: consultationId,
      api: api,
    );
    await controller.load();
    final lab = controller.orders.first;
    controller.beginEdit(lab);
    controller.updateValue('CBC updated');
    await controller.save();
    expect(
      controller.orders.firstWhere((value) => value.id == lab.id).version,
      2,
    );
    controller.dispose();
  });

  test(
    'cross-device stale update conflicts without duplicate or overwrite',
    () async {
      final api = _FakeClinicalOrderApi();
      final created = await api.create(
        consultationId: consultationId,
        idempotencyKey: 'angular-create',
        category: ClinicalOrderCategory.lab,
        definition: ClinicalOrderDefinition.forValue(
          ClinicalOrderCategory.lab,
          'CBC',
        ),
      );
      final flutter = ClinicalOrderController(
        consultationId: consultationId,
        api: api,
      );
      await flutter.load();
      expect(flutter.orders.single.id, created.id);
      flutter.beginEdit(flutter.orders.single);
      flutter.updateValue('CBC v2');
      await flutter.save();
      final angularV2 = (await api.list(consultationId)).single;
      expect(angularV2.version, 2);
      await flutter.load();
      final staleV2 = flutter.orders.single;
      await api.update(
        consultationId: consultationId,
        idempotencyKey: 'angular-v3',
        order: angularV2,
        definition: ClinicalOrderDefinition.forValue(
          ClinicalOrderCategory.lab,
          'CBC v3',
        ),
      );
      flutter.beginEdit(staleV2);
      flutter.updateValue('stale mobile value');
      await flutter.save();
      expect(flutter.conflict, isTrue);
      expect(
        flutter.editor?.draft.value(ClinicalOrderCategory.lab),
        'stale mobile value',
      );
      expect(api.orders.length, 1);
      expect(
        api.orders.single.definition.value(ClinicalOrderCategory.lab),
        'CBC v3',
      );
      flutter.dispose();
    },
  );

  test('finalized order is immutable', () async {
    final api = _FakeClinicalOrderApi();
    final order = await api.create(
      consultationId: consultationId,
      idempotencyKey: 'create',
      category: ClinicalOrderCategory.imaging,
      definition: ClinicalOrderDefinition.forValue(
        ClinicalOrderCategory.imaging,
        'MRI',
      ),
    );
    final controller = ClinicalOrderController(
      consultationId: consultationId,
      api: api,
    );
    await controller.load();
    await controller.finalize(order);
    expect(controller.orders.single.status, ClinicalOrderStatus.finalized);
    expect(controller.orders.single.version, 2);
    expect(
      () => api.update(
        consultationId: consultationId,
        idempotencyKey: 'late',
        order: controller.orders.single,
        definition: ClinicalOrderDefinition.forValue(
          ClinicalOrderCategory.imaging,
          'CT',
        ),
      ),
      throwsA(isA<DioException>()),
    );
    controller.dispose();
  });

  test('dirty realtime invalidation preserves volatile input', () async {
    final api = _FakeClinicalOrderApi();
    final order = await api.create(
      consultationId: consultationId,
      idempotencyKey: 'create',
      category: ClinicalOrderCategory.referral,
      definition: ClinicalOrderDefinition.forValue(
        ClinicalOrderCategory.referral,
        'Cardiology',
      ),
    );
    final controller = ClinicalOrderController(
      consultationId: consultationId,
      api: api,
    );
    await controller.load();
    controller.beginEdit(order);
    controller.updateValue('Neurology');
    await controller.invalidate(
      ScheduledCareInvalidationEvent(
        eventId: '22222222-2222-4222-8222-222222222222',
        type: ScheduledCareEventType.unknown,
        rawEventType: 'CLINICAL_ORDER_UPDATED',
        resourceType: ScheduledCareResourceType.clinicalOrder,
        resourceId: order.id,
        version: 2,
        occurredAt: DateTime.utc(2026, 10, 25),
      ),
    );
    expect(controller.newerVersionAvailable, isTrue);
    expect(controller.editor?.draft.targetSpecialty, 'Neurology');
    controller.dispose();
  });

  test(
    'realtime parser accepts PHI-free order reference and deactivation clears data',
    () async {
      final event = ScheduledCareInvalidationEvent.tryParse(
        '''{"eventId":"22222222-2222-4222-8222-222222222222","eventType":"CLINICAL_ORDER_UPDATED","resourceType":"CLINICAL_ORDER","resourceId":"33333333-3333-4333-8333-333333333333","version":2,"occurredAt":"2026-10-25T10:00:00Z"}''',
      );
      expect(event?.resourceType, ScheduledCareResourceType.clinicalOrder);
      final controller = ClinicalOrderController(
        consultationId: consultationId,
        api: _FakeClinicalOrderApi(),
      );
      final target = ClinicalOrderRealtimeTarget(controller)..activate();
      await controller.load();
      target.deactivate();
      expect(controller.orders, isEmpty);
      expect(controller.editor, isNull);
      target.dispose();
      controller.dispose();
    },
  );
}

class _FakeClinicalOrderApi implements ClinicalOrderApiContract {
  List<ClinicalOrder> orders = [];
  int sequence = 1;
  @override
  Future<List<ClinicalOrder>> list(String consultationId) async =>
      List.of(orders);
  @override
  Future<ClinicalOrder> create({
    required String consultationId,
    required String idempotencyKey,
    required ClinicalOrderCategory category,
    required ClinicalOrderDefinition definition,
  }) async {
    final order = ClinicalOrder(
      id: '00000000-0000-4000-8000-${sequence.toString().padLeft(12, '0')}',
      consultationId: consultationId,
      category: category,
      status: ClinicalOrderStatus.draft,
      version: 1,
      schemaVersion: 1,
      definition: definition,
    );
    sequence++;
    orders = [...orders, order];
    return order;
  }

  @override
  Future<ClinicalOrder> update({
    required String consultationId,
    required String idempotencyKey,
    required ClinicalOrder order,
    required ClinicalOrderDefinition definition,
  }) async {
    final current = orders.firstWhere((value) => value.id == order.id);
    if (current.status == ClinicalOrderStatus.finalized ||
        current.version != order.version) {
      throw _conflict(
        current.status == ClinicalOrderStatus.finalized
            ? 'CLINICAL_ORDER_ALREADY_FINALIZED'
            : 'CLINICAL_ORDER_VERSION_CONFLICT',
      );
    }
    final saved = ClinicalOrder(
      id: current.id,
      consultationId: current.consultationId,
      category: current.category,
      status: current.status,
      version: current.version + 1,
      schemaVersion: 1,
      definition: definition,
    );
    orders = orders
        .map((value) => value.id == saved.id ? saved : value)
        .toList();
    return saved;
  }

  @override
  Future<ClinicalOrder> finalize({
    required String consultationId,
    required String idempotencyKey,
    required ClinicalOrder order,
  }) async {
    final current = orders.firstWhere((value) => value.id == order.id);
    if (current.status == ClinicalOrderStatus.finalized ||
        current.version != order.version) {
      throw _conflict('CLINICAL_ORDER_VERSION_CONFLICT');
    }
    final saved = ClinicalOrder(
      id: current.id,
      consultationId: current.consultationId,
      category: current.category,
      status: ClinicalOrderStatus.finalized,
      version: current.version + 1,
      schemaVersion: 1,
      definition: current.definition,
    );
    orders = orders
        .map((value) => value.id == saved.id ? saved : value)
        .toList();
    return saved;
  }

  DioException _conflict(String code) => DioException(
    requestOptions: RequestOptions(path: '/clinical-orders'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/clinical-orders'),
      statusCode: 409,
      data: {'code': code},
    ),
    type: DioExceptionType.badResponse,
  );
}
