import 'package:flutter/foundation.dart';

@immutable
class MedicalShareQr {
  const MedicalShareQr({required this.payload, required this.expiresAt});

  final String payload;
  final DateTime expiresAt;

  factory MedicalShareQr.fromJson(Map<String, dynamic> json) {
    final payload = json['qrPayload'];
    final expiresAt = json['expiresAt'];
    if (payload is! String || payload.trim().isEmpty) {
      throw const FormatException('Missing QR payload.');
    }
    if (expiresAt is! String) {
      throw const FormatException('Missing QR expiry.');
    }
    final parsedExpiry = DateTime.tryParse(expiresAt);
    if (parsedExpiry == null) {
      throw const FormatException('Invalid QR expiry.');
    }
    return MedicalShareQr(
      payload: payload.trim(),
      expiresAt: parsedExpiry.toUtc(),
    );
  }
}

enum MedicalShareQrStatus { idle, loading, ready, preview, expired, error }
