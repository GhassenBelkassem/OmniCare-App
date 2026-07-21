import 'package:flutter/foundation.dart';

class MedicationEntry {
  String? medicationId;
  String name;
  String dosage;
  String frequency;

  MedicationEntry({
    this.medicationId,
    required this.name,
    required this.dosage,
    required this.frequency,
  });

  Map<String, dynamic> toJson() => {
    'medicationId': medicationId,
    'name': name,
    'dosage': dosage,
    'frequency': frequency,
  };
}

class AllergyEntry {
  String name;
  String severity;
  bool lifeSafety;

  AllergyEntry({
    required this.name,
    required this.severity,
    required this.lifeSafety,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'severity': severity,
    'lifeSafety': lifeSafety,
  };
}

class MedicalDocument {
  String documentName;
  String documentType;
  DateTime date;
  String? filePath;

  MedicalDocument({
    required this.documentName,
    required this.documentType,
    required this.date,
    this.filePath,
  });

  Map<String, dynamic> toJson() => {
    'documentName': documentName,
    'documentType': documentType,
    'date': date.toIso8601String(),
    'filePath': filePath,
  };
}

class UserOnboardingProvider extends ChangeNotifier {
  String? email;
  String? phoneNumber;
  bool emailVerified = false;
  bool phoneVerified = false;
  String? language;
  String? firstName;
  String? lastName;
  DateTime? dateOfBirth;
  String? gender;

  String? bloodGroup;
  int? heightCm;
  double? weightKg;
  List<AllergyEntry> allergies = [];
  List<String> chronicConditions = [];
  List<MedicationEntry> medications = [];
  List<MedicalDocument> medicalDocuments = [];

  void setEmail(String value) {
    email = value;
    notifyListeners();
  }

  void setPhoneNumber(String value) {
    phoneNumber = value;
    notifyListeners();
  }

  void setEmailVerified(bool value) {
    emailVerified = value;
    notifyListeners();
  }

  void setPhoneVerified(bool value) {
    phoneVerified = value;
    notifyListeners();
  }

  void setLanguage(String value) {
    language = value;
    notifyListeners();
  }

  void setBasicProfile({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String gender,
  }) {
    this.firstName = firstName;
    this.lastName = lastName;
    this.dateOfBirth = dateOfBirth;
    this.gender = gender;
    notifyListeners();
  }

  void setBloodGroup(String? value) {
    bloodGroup = value;
    notifyListeners();
  }

  void setBodyMeasurements({int? heightCm, double? weightKg}) {
    this.heightCm = heightCm;
    this.weightKg = weightKg;
    notifyListeners();
  }

  void setAllergies(List<AllergyEntry> value) {
    allergies = value;
    notifyListeners();
  }

  void addChronicCondition(String condition) {
    if (!chronicConditions.contains(condition)) {
      chronicConditions.add(condition);
      notifyListeners();
    }
  }

  void removeChronicCondition(String condition) {
    chronicConditions.remove(condition);
    notifyListeners();
  }

  void addMedication(MedicationEntry medication) {
    medications.add(medication);
    notifyListeners();
  }

  void removeMedication(int index) {
    if (index >= 0 && index < medications.length) {
      medications.removeAt(index);
      notifyListeners();
    }
  }

  void updateMedication(int index, MedicationEntry medication) {
    if (index >= 0 && index < medications.length) {
      medications[index] = medication;
      notifyListeners();
    }
  }

  void addMedicalDocument(MedicalDocument document) {
    medicalDocuments.add(document);
    notifyListeners();
  }

  void removeMedicalDocument(int index) {
    if (index >= 0 && index < medicalDocuments.length) {
      medicalDocuments.removeAt(index);
      notifyListeners();
    }
  }

  Map<String, dynamic> toMedicalPassportJson() {
    return {
      'bloodGroup': bloodGroup,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'allergies': allergies.map((a) => a.toJson()).toList(),
      'chronicConditions': chronicConditions,
      'medications': medications.map((m) => m.toJson()).toList(),
      'medicalDocuments': medicalDocuments.map((d) => d.toJson()).toList(),
    };
  }

  Map<String, dynamic> toFamilyMemberJson() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'emailVerified': emailVerified,
      'phoneVerified': phoneVerified,
      'language': language,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'medicalPassport': toMedicalPassportJson(),
    };
  }

  void reset() {
    email = null;
    phoneNumber = null;
    emailVerified = false;
    phoneVerified = false;
    language = null;
    firstName = null;
    lastName = null;
    dateOfBirth = null;
    gender = null;
    bloodGroup = null;
    heightCm = null;
    weightKg = null;
    allergies.clear();
    chronicConditions.clear();
    medications.clear();
    medicalDocuments.clear();
    notifyListeners();
  }
}
