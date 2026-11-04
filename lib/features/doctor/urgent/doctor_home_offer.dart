import 'package:flutter/foundation.dart';

enum DoctorHomeOfferStatus {
  pendingResponse,
  acceptedHeld,
  holdExpired,
  doctorWithdrawn,
  declined,
  selectedCommitted,
  notSelected,
  selectionClosed,
  invalidated,
  expired,
  superseded,
  cancelled;

  static DoctorHomeOfferStatus parse(String value) => switch (value) {
    'PENDING_RESPONSE' => DoctorHomeOfferStatus.pendingResponse,
    'ACCEPTED_HELD' => DoctorHomeOfferStatus.acceptedHeld,
    'HOLD_EXPIRED' => DoctorHomeOfferStatus.holdExpired,
    'DOCTOR_WITHDRAWN' => DoctorHomeOfferStatus.doctorWithdrawn,
    'DECLINED' => DoctorHomeOfferStatus.declined,
    'SELECTED_COMMITTED' => DoctorHomeOfferStatus.selectedCommitted,
    'NOT_SELECTED' => DoctorHomeOfferStatus.notSelected,
    'SELECTION_CLOSED' => DoctorHomeOfferStatus.selectionClosed,
    'INVALIDATED' => DoctorHomeOfferStatus.invalidated,
    'EXPIRED' => DoctorHomeOfferStatus.expired,
    'SUPERSEDED' => DoctorHomeOfferStatus.superseded,
    'CANCELLED' => DoctorHomeOfferStatus.cancelled,
    _ => throw const FormatException('Unknown HOME offer status.'),
  };

  String get frenchLabel => switch (this) {
    pendingResponse => 'Demande reçue',
    acceptedHeld => 'En attente du choix du patient',
    holdExpired => 'Maintien expiré',
    doctorWithdrawn => 'Retrait du médecin',
    declined => 'Offre déclinée',
    selectedCommitted => 'Médecin confirmé par le patient',
    notSelected => 'Autre médecin sélectionné',
    selectionClosed => 'Sélection clôturée',
    invalidated => 'Offre invalidée',
    expired => 'Offre expirée',
    superseded => 'Offre remplacée',
    cancelled => 'Offre annulée',
  };
}

enum DoctorHomeWithdrawalReason {
  noLongerAvailable,
  unexpectedDelay,
  otherOperational;

  static DoctorHomeWithdrawalReason parse(String value) => switch (value) {
    'NO_LONGER_AVAILABLE' => DoctorHomeWithdrawalReason.noLongerAvailable,
    'UNEXPECTED_DELAY' => DoctorHomeWithdrawalReason.unexpectedDelay,
    'OTHER_OPERATIONAL' => DoctorHomeWithdrawalReason.otherOperational,
    _ => throw const FormatException('Unknown HOME withdrawal reason.'),
  };

  String get frenchLabel => switch (this) {
    noLongerAvailable => 'Vous n’étiez plus disponible.',
    unexpectedDelay => 'Un retard imprévu a été signalé.',
    otherOperational => 'Un motif opérationnel a été signalé.',
  };
}

@immutable
class DoctorHomeOffer {
  const DoctorHomeOffer({
    required this.offerId,
    required this.status,
    required this.revision,
    required this.responseDeadlineAt,
    required this.holdCurrentlyValid,
    required this.replayed,
    required this.updatedAt,
    required this.evaluatedAt,
    this.holdExpiresAt,
    this.quotedHomeFeeTnd,
    this.currency,
    this.withdrawalReason,
  });

  final String offerId;
  final DoctorHomeOfferStatus status;
  final int revision;
  final DateTime responseDeadlineAt;
  final DateTime? holdExpiresAt;
  final bool holdCurrentlyValid;
  final String? quotedHomeFeeTnd;
  final String? currency;
  final DoctorHomeWithdrawalReason? withdrawalReason;
  final bool replayed;
  final DateTime updatedAt;
  final DateTime evaluatedAt;

  bool get isPending => status == DoctorHomeOfferStatus.pendingResponse;

  bool get isAcceptedHold => status == DoctorHomeOfferStatus.acceptedHeld;

  bool get isTerminal => !isPending && !isAcceptedHold;

  String get shortIdentity {
    final compact = offerId.replaceAll('-', '');
    return compact.length <= 8
        ? compact.toUpperCase()
        : compact.substring(compact.length - 8).toUpperCase();
  }

  String get presentationStatus => isAcceptedHold && !holdCurrentlyValid
      ? 'Maintien arrivé à expiration'
      : status.frenchLabel;
}

DoctorHomeOffer parseDoctorHomeOffer(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected a HOME offer object.');
  }
  final json = value.cast<Object?, Object?>();
  final offerId = _requiredString(json, 'offerId');
  if (!_uuidPattern.hasMatch(offerId)) {
    throw const FormatException('Invalid HOME offer identity.');
  }
  final status = DoctorHomeOfferStatus.parse(_requiredString(json, 'status'));
  final revision = json['revision'];
  if (revision is! int || revision < 0) {
    throw const FormatException('Invalid HOME offer revision.');
  }
  final responseDeadlineAt = _requiredDateTime(json, 'responseDeadlineAt');
  final holdExpiresAt = _nullableDateTime(json, 'holdExpiresAt');
  final holdCurrentlyValid = json['holdCurrentlyValid'];
  final replayed = json['replayed'];
  if (holdCurrentlyValid is! bool || replayed is! bool) {
    throw const FormatException('Invalid HOME offer flags.');
  }

  final rawFee = json['quotedHomeFeeTnd'];
  final rawCurrency = json['currency'];
  final fee = _fee(rawFee);
  if ((fee == null) != (rawCurrency == null) ||
      (rawCurrency != null && rawCurrency != 'TND')) {
    throw const FormatException('Invalid HOME offer currency shape.');
  }

  final rawReason = json['withdrawalReason'];
  final reason = rawReason == null
      ? null
      : rawReason is String
      ? DoctorHomeWithdrawalReason.parse(rawReason)
      : throw const FormatException('Invalid HOME withdrawal reason.');

  if (status == DoctorHomeOfferStatus.pendingResponse &&
      (holdExpiresAt != null ||
          holdCurrentlyValid ||
          fee != null ||
          reason != null)) {
    throw const FormatException('Invalid pending HOME offer shape.');
  }
  if (status == DoctorHomeOfferStatus.acceptedHeld &&
      (holdExpiresAt == null || fee == null || reason != null)) {
    throw const FormatException('Invalid accepted HOME hold shape.');
  }
  if (holdCurrentlyValid &&
      (status != DoctorHomeOfferStatus.acceptedHeld ||
          holdExpiresAt == null ||
          !holdExpiresAt.isAfter(_requiredDateTime(json, 'evaluatedAt')))) {
    throw const FormatException('Invalid current HOME hold validity.');
  }
  if ((status == DoctorHomeOfferStatus.doctorWithdrawn) != (reason != null)) {
    throw const FormatException('Invalid HOME withdrawal state shape.');
  }

  return DoctorHomeOffer(
    offerId: offerId,
    status: status,
    revision: revision,
    responseDeadlineAt: responseDeadlineAt,
    holdExpiresAt: holdExpiresAt,
    holdCurrentlyValid: holdCurrentlyValid,
    quotedHomeFeeTnd: fee,
    currency: rawCurrency as String?,
    withdrawalReason: reason,
    replayed: replayed,
    updatedAt: _requiredDateTime(json, 'updatedAt'),
    evaluatedAt: _requiredDateTime(json, 'evaluatedAt'),
  );
}

List<DoctorHomeOffer> parseDoctorHomeOfferList(Object? value) {
  if (value is! List) {
    throw const FormatException('Expected a HOME offer list.');
  }
  return List.unmodifiable(value.map(parseDoctorHomeOffer));
}

String _requiredString(Map<Object?, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing $field.');
  }
  return value;
}

DateTime _requiredDateTime(Map<Object?, Object?> json, String field) {
  final value = _requiredString(json, field);
  return DateTime.tryParse(value)?.toUtc() ??
      (throw FormatException('Invalid $field.'));
}

DateTime? _nullableDateTime(Map<Object?, Object?> json, String field) {
  if (json[field] == null) return null;
  return _requiredDateTime(json, field);
}

String? _fee(Object? value) {
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < 0) {
    throw const FormatException('Invalid HOME fee.');
  }
  final scaled = value * 1000;
  if ((scaled - scaled.round()).abs() > 0.000001 || value > 99999999.999) {
    throw const FormatException('Invalid HOME fee scale.');
  }
  return value.toStringAsFixed(3);
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
