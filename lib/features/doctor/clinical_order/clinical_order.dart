import 'dart:convert';

enum ClinicalOrderCategory { lab, imaging, referral }

enum ClinicalOrderStatus { draft, finalized }

extension ClinicalOrderCategoryWire on ClinicalOrderCategory {
  String get wire => switch (this) {
    ClinicalOrderCategory.lab => 'LAB',
    ClinicalOrderCategory.imaging => 'IMAGING',
    ClinicalOrderCategory.referral => 'REFERRAL',
  };
  String get label => switch (this) {
    ClinicalOrderCategory.lab => 'Laboratory',
    ClinicalOrderCategory.imaging => 'Imaging',
    ClinicalOrderCategory.referral => 'Referral',
  };
  String get fieldLabel => switch (this) {
    ClinicalOrderCategory.lab => 'Requested examination',
    ClinicalOrderCategory.imaging => 'Requested study',
    ClinicalOrderCategory.referral => 'Target specialty',
  };
}

class ClinicalOrderDefinition {
  const ClinicalOrderDefinition({
    this.requestedExamination,
    this.requestedStudy,
    this.targetSpecialty,
  });
  final String? requestedExamination;
  final String? requestedStudy;
  final String? targetSpecialty;

  factory ClinicalOrderDefinition.forValue(
    ClinicalOrderCategory category,
    String value,
  ) {
    final normalized = value.trim().isEmpty ? null : value;
    return switch (category) {
      ClinicalOrderCategory.lab => ClinicalOrderDefinition(
        requestedExamination: normalized,
      ),
      ClinicalOrderCategory.imaging => ClinicalOrderDefinition(
        requestedStudy: normalized,
      ),
      ClinicalOrderCategory.referral => ClinicalOrderDefinition(
        targetSpecialty: normalized,
      ),
    };
  }
  factory ClinicalOrderDefinition.fromJson(Map<String, dynamic> json) =>
      ClinicalOrderDefinition(
        requestedExamination: _text(json['requestedExamination']),
        requestedStudy: _text(json['requestedStudy']),
        targetSpecialty: _text(json['targetSpecialty']),
      );
  String value(ClinicalOrderCategory category) => switch (category) {
    ClinicalOrderCategory.lab => requestedExamination ?? '',
    ClinicalOrderCategory.imaging => requestedStudy ?? '',
    ClinicalOrderCategory.referral => targetSpecialty ?? '',
  };
  Map<String, dynamic> toJson() => {
    'requestedExamination': requestedExamination,
    'requestedStudy': requestedStudy,
    'targetSpecialty': targetSpecialty,
  };
  String fingerprint() => jsonEncode(toJson());
}

class ClinicalOrder {
  const ClinicalOrder({
    required this.id,
    required this.consultationId,
    required this.category,
    required this.status,
    required this.version,
    required this.schemaVersion,
    required this.definition,
  });
  final String id;
  final String consultationId;
  final ClinicalOrderCategory category;
  final ClinicalOrderStatus status;
  final int version;
  final int schemaVersion;
  final ClinicalOrderDefinition definition;

  factory ClinicalOrder.fromJson(Map<String, dynamic> json) {
    final id = json['clinicalOrderId'];
    final consultation = json['consultationId'];
    final version = json['clinicalOrderVersion'];
    final schema = json['schemaVersion'];
    final definition = json['definition'];
    if (id is! String ||
        consultation is! String ||
        version is! int ||
        version < 1 ||
        schema != 1 ||
        definition is! Map) {
      throw const FormatException('Invalid clinical order response.');
    }
    return ClinicalOrder(
      id: id,
      consultationId: consultation,
      category: _category(json['category']),
      status: _status(json['status']),
      version: version,
      schemaVersion: schema as int,
      definition: ClinicalOrderDefinition.fromJson(
        definition.cast<String, dynamic>(),
      ),
    );
  }
}

ClinicalOrderCategory _category(Object? value) => switch (value) {
  'LAB' => ClinicalOrderCategory.lab,
  'IMAGING' => ClinicalOrderCategory.imaging,
  'REFERRAL' => ClinicalOrderCategory.referral,
  _ => throw const FormatException('Invalid clinical order category.'),
};
ClinicalOrderStatus _status(Object? value) => switch (value) {
  'DRAFT' => ClinicalOrderStatus.draft,
  'FINALIZED' => ClinicalOrderStatus.finalized,
  _ => throw const FormatException('Invalid clinical order status.'),
};
String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;
