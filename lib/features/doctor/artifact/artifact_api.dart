import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import 'artifact.dart';

class ArtifactApi {
  const ArtifactApi(this._client);
  final AppHttpClient _client;
  Future<List<OfficialArtifact>> listDoctor(String consultation) async {
    final data = _map(
      (await _client.dio.get<dynamic>(
        '/doctor/consultations/$consultation/artifacts',
      )).data,
    );
    return ((data['artifacts'] as List?) ?? const [])
        .map((e) => OfficialArtifact.fromJson(_map(e)))
        .toList(growable: false);
  }

  Future<List<OfficialArtifact>> listPatient(
    String consultation,
    String subjectType,
    String? familyMemberId,
  ) async {
    final query = <String, dynamic>{'subjectType': subjectType};
    if (familyMemberId != null) {
      query['familyMemberId'] = familyMemberId;
    }
    final data = _map(
      (await _client.dio.get<dynamic>(
        '/patient/consultations/$consultation/artifacts',
        queryParameters: query,
      )).data,
    );
    return ((data['artifacts'] as List?) ?? const [])
        .map((e) => OfficialArtifact.fromJson(_map(e)))
        .toList(growable: false);
  }

  Future<OfficialArtifact> createCertificate(
    String consultation,
    String type,
    Map<String, dynamic> definition,
    String idempotencyKey,
  ) async => OfficialArtifact.fromJson(
    _map(
      (await _client.dio.post<dynamic>(
        '/doctor/consultations/$consultation/artifacts',
        data: {'artifactType': type, 'definition': definition},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      )).data,
    ),
  );
  Future<OfficialArtifact> createSource(
    String consultation,
    String type,
    String source,
    int version,
    String idempotencyKey,
  ) async => OfficialArtifact.fromJson(
    _map(
      (await _client.dio.post<dynamic>(
        '/doctor/consultations/$consultation/artifacts',
        data: {
          'artifactType': type,
          'sourceResourceId': source,
          'sourceResourceVersion': version,
          'definition': {},
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      )).data,
    ),
  );
  Future<OfficialArtifact> update(
    String consultation,
    OfficialArtifact value,
    Map<String, dynamic> definition,
    String idempotencyKey,
  ) async => OfficialArtifact.fromJson(
    _map(
      (await _client.dio.put<dynamic>(
        '/doctor/consultations/$consultation/artifacts/${value.id}',
        data: {
          'expectedArtifactVersion': value.version,
          'definition': definition,
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      )).data,
    ),
  );
  Future<OfficialArtifact> finalize(
    String consultation,
    OfficialArtifact value,
    String idempotencyKey,
  ) async => OfficialArtifact.fromJson(
    _map(
      (await _client.dio.post<dynamic>(
        '/doctor/consultations/$consultation/artifacts/${value.id}/finalize',
        data: {'expectedArtifactVersion': value.version, 'confirmation': true},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      )).data,
    ),
  );
  Future<Uint8List> downloadDoctor(String consultation, String artifact) async {
    final response = await _client.dio.get<List<int>>(
      '/doctor/consultations/$consultation/artifacts/$artifact/download',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Invalid PDF response');
    }
    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> downloadPatient(
    String consultation,
    String artifact,
    String subjectType,
    String? familyMemberId,
  ) async {
    final query = <String, dynamic>{'subjectType': subjectType};
    if (familyMemberId != null) {
      query['familyMemberId'] = familyMemberId;
    }
    final response = await _client.dio.get<List<int>>(
      '/patient/consultations/$consultation/artifacts/$artifact/download',
      queryParameters: query,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid artifact response');
    }
    return value.cast<String, dynamic>();
  }
}
