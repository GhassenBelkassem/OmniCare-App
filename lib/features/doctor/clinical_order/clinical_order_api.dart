import 'package:dio/dio.dart';
import '../../../core/network/app_http_client.dart';
import 'clinical_order.dart';

abstract interface class ClinicalOrderApiContract {
  Future<List<ClinicalOrder>> list(String consultationId);
  Future<ClinicalOrder> create({
    required String consultationId,
    required String idempotencyKey,
    required ClinicalOrderCategory category,
    required ClinicalOrderDefinition definition,
  });
  Future<ClinicalOrder> update({
    required String consultationId,
    required String idempotencyKey,
    required ClinicalOrder order,
    required ClinicalOrderDefinition definition,
  });
  Future<ClinicalOrder> finalize({
    required String consultationId,
    required String idempotencyKey,
    required ClinicalOrder order,
  });
}

class ClinicalOrderApi implements ClinicalOrderApiContract {
  const ClinicalOrderApi(this._client);
  final AppHttpClient _client;
  String _base(String id) =>
      '/doctor/consultations/${id.trim()}/clinical-orders';

  @override
  Future<List<ClinicalOrder>> list(String consultationId) async {
    final response = await _client.dio.get<dynamic>(_base(consultationId));
    final root = _object(response.data);
    final values = root['orders'];
    if (values is! List) {
      throw const FormatException('Invalid clinical order list.');
    }
    return values
        .map((value) => ClinicalOrder.fromJson(_object(value)))
        .toList(growable: false);
  }

  @override
  Future<ClinicalOrder> create({
    required String consultationId,
    required String idempotencyKey,
    required ClinicalOrderCategory category,
    required ClinicalOrderDefinition definition,
  }) async {
    final response = await _client.dio.post<dynamic>(
      _base(consultationId),
      data: {'category': category.wire, 'definition': definition.toJson()},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return ClinicalOrder.fromJson(_object(response.data));
  }

  @override
  Future<ClinicalOrder> update({
    required String consultationId,
    required String idempotencyKey,
    required ClinicalOrder order,
    required ClinicalOrderDefinition definition,
  }) async {
    final response = await _client.dio.put<dynamic>(
      '${_base(consultationId)}/${order.id}',
      data: _mutation(order, definition),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return ClinicalOrder.fromJson(_object(response.data));
  }

  @override
  Future<ClinicalOrder> finalize({
    required String consultationId,
    required String idempotencyKey,
    required ClinicalOrder order,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '${_base(consultationId)}/${order.id}/finalize',
      data: _mutation(order, order.definition),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return ClinicalOrder.fromJson(_object(response.data));
  }

  Map<String, dynamic> _mutation(
    ClinicalOrder order,
    ClinicalOrderDefinition definition,
  ) => {
    'expectedClinicalOrderVersion': order.version,
    'category': order.category.wire,
    'definition': definition.toJson(),
  };
  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid clinical order response.');
    }
    return value.cast<String, dynamic>();
  }
}
