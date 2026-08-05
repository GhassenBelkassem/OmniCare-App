import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';

void main() {
  const response = <String, dynamic>{
    'userId': 'user-1',
    'firstName': 'Amina',
    'lastName': 'Ben Salah',
    'displayName': 'Amina Ben Salah',
    'dateOfBirth': '1992-04-18',
    'gender': 'F',
    'photoUrl': null,
    'primaryPhone': <String, dynamic>{
      'value': '+21698123456',
      'verified': true,
    },
    'primaryEmail': <String, dynamic>{
      'value': 'amina@example.tn',
      'verified': false,
    },
    'onboardingCompleted': true,
    'onboardingStep': 4,
    'preferredLanguage': 'fr',
    'notificationMedications': true,
    'notificationAppointments': false,
    'notificationPassport': true,
    'updatedAt': '2026-08-04T10:15:30Z',
  };

  test('parses the non-medical profile contract', () {
    final profile = PatientProfile.fromJson(response);

    expect(profile.primaryPhone?.value, '+21698123456');
    expect(profile.primaryPhone?.verified, isTrue);
    expect(profile.primaryEmail?.verified, isFalse);
    expect(profile.dateOfBirth, DateTime.utc(1992, 4, 18));
    expect(profile.notifications.appointments, isFalse);
  });

  test('serializes only supported non-medical update fields', () {
    final json = PatientProfileUpdate(
      firstName: '  Amina ',
      lastName: ' Ben Salah  ',
      dateOfBirth: DateTime.utc(1992, 4, 18),
      gender: 'F',
      preferredLanguage: 'ar',
      notificationAppointments: false,
    ).toJson();

    expect(json, <String, dynamic>{
      'firstName': 'Amina',
      'lastName': 'Ben Salah',
      'dateOfBirth': '1992-04-18',
      'gender': 'F',
      'preferredLanguage': 'ar',
      'notificationAppointments': false,
    });
    expect(json.containsKey('patientId'), isFalse);
    expect(json.containsKey('bloodType'), isFalse);
    expect(json.containsKey('photoUrl'), isFalse);
  });

  test('rejects malformed verified contacts', () {
    final malformed = Map<String, dynamic>.from(response)
      ..['primaryPhone'] = <String, dynamic>{'value': '+21698123456'};

    expect(() => PatientProfile.fromJson(malformed), throwsFormatException);
  });
}
