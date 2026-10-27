import 'dart:math';

class OfficialArtifact {
  const OfficialArtifact({
    required this.id,
    required this.type,
    required this.version,
    required this.renderVersion,
    required this.status,
    required this.renderStatus,
    this.sourceId,
    this.sourceVersion,
    this.definition = const {},
    this.verificationReference,
  });
  final String id, type, status, renderStatus;
  final int version;
  final int renderVersion;
  final String? sourceId, verificationReference;
  final int? sourceVersion;
  final Map<String, dynamic> definition;
  bool get finalized => status == 'FINALIZED';
  bool get ready => renderStatus == 'READY';
  factory OfficialArtifact.fromJson(Map<String, dynamic> json) =>
      OfficialArtifact(
        id: json['artifactId'] as String,
        type: json['artifactType'] as String,
        version: json['artifactVersion'] as int,
        renderVersion: json['renderVersion'] as int,
        status: json['status'] as String,
        renderStatus: json['renderStatus'] as String,
        sourceId: json['sourceResourceId'] as String?,
        sourceVersion: json['sourceResourceVersion'] as int?,
        definition:
            (json['definition'] as Map?)?.cast<String, dynamic>() ?? const {},
        verificationReference: json['verificationReference'] as String?,
      );
}

/// Volatile-only mutation key registry for ambiguity-safe retries.
class ArtifactMutationKeys {
  final Map<String, String> _keys = {};

  String acquire(String operationFingerprint) => _keys.putIfAbsent(
    operationFingerprint,
    () => newArtifactMutationKey(operationFingerprint.split(':').first),
  );

  void complete(String operationFingerprint) =>
      _keys.remove(operationFingerprint);

  void clear() => _keys.clear();
}

String newArtifactMutationKey(String operation) {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final token = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'artifact-$operation:$token';
}
