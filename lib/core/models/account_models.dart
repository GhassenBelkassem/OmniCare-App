class AccountFullProfile {
  final AccountUser user;
  final List<AccountFamilyMember> familyMembers;
  final List<AccountMedicalDocument> documents;

  AccountFullProfile({
    required this.user,
    required this.familyMembers,
    required this.documents,
  });

  factory AccountFullProfile.fromJson(Map<String, dynamic> json) {
    final userJson =
        (json['user'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final familyJson = (json['familyMembers'] as List?) ?? const [];
    final documentsJson = (json['documents'] as List?) ?? const [];

    return AccountFullProfile(
      user: AccountUser.fromJson(userJson),
      familyMembers: familyJson
          .whereType<Map>()
          .map((e) => AccountFamilyMember.fromJson(e.cast<String, dynamic>()))
          .toList(),
      documents: documentsJson
          .whereType<Map>()
          .map(
            (e) => AccountMedicalDocument.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'familyMembers': familyMembers.map((e) => e.toJson()).toList(),
      'documents': documents.map((e) => e.toJson()).toList(),
    };
  }
}

String? _bloodGroupFromBackend(String? raw) {
  if (raw == null) return null;
  final v = raw.trim();
  if (v.isEmpty) return null;
  return switch (v) {
    'A_POS' => 'A+',
    'A_NEG' => 'A-',
    'B_POS' => 'B+',
    'B_NEG' => 'B-',
    'AB_POS' => 'AB+',
    'AB_NEG' => 'AB-',
    'O_POS' => 'O+',
    'O_NEG' => 'O-',
    _ => v,
  };
}

class AccountUser {
  final String email;
  final String name;
  final String? role;
  final String? providerId;
  final String? providerType;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? bloodGroup;
  final Map<String, dynamic>? medicalInfo;

  AccountUser({
    required this.email,
    required this.name,
    this.role,
    this.providerId,
    this.providerType,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.bloodGroup,
    this.medicalInfo,
  });

  factory AccountUser.fromJson(Map<String, dynamic> json) {
    final directFirst = json['firstName']?.toString();
    final directLast = json['lastName']?.toString();

    final profileJson = (json['profile'] is Map)
        ? (json['profile'] as Map).cast<String, dynamic>()
        : null;
    final profileFirst = profileJson?['firstName']?.toString();
    final profileLast = profileJson?['lastName']?.toString();

    String resolvedName = (json['name'] ?? '').toString();
    final String resolvedFirst = (directFirst ?? profileFirst ?? '').toString();
    final String resolvedLast = (directLast ?? profileLast ?? '').toString();
    if (resolvedName.trim().isEmpty &&
        (resolvedFirst.trim().isNotEmpty || resolvedLast.trim().isNotEmpty)) {
      resolvedName = [
        resolvedFirst,
        resolvedLast,
      ].where((e) => e.trim().isNotEmpty).join(' ');
    }

    final providerJson = (json['provider'] is Map)
        ? (json['provider'] as Map).cast<String, dynamic>()
        : null;
    final resolvedProviderId =
        json['providerId']?.toString() ?? providerJson?['id']?.toString();
    final resolvedProviderType =
        json['providerType']?.toString() ??
        providerJson?['providerType']?.toString() ??
        providerJson?['type']?.toString();

    return AccountUser(
      email: (json['email'] ?? '').toString(),
      name: resolvedName,
      role: json['role']?.toString(),
      providerId: resolvedProviderId,
      providerType: resolvedProviderType,
      firstName: resolvedFirst.trim().isEmpty ? null : resolvedFirst,
      lastName: resolvedLast.trim().isEmpty ? null : resolvedLast,
      phoneNumber: json['phoneNumber']?.toString(),
      bloodGroup: _bloodGroupFromBackend(json['bloodGroup']?.toString()),
      medicalInfo: (json['medicalInfo'] is Map)
          ? (json['medicalInfo'] as Map).cast<String, dynamic>()
          : null,
    );
  }

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final derived = [
      firstName ?? '',
      lastName ?? '',
    ].where((e) => e.trim().isNotEmpty).join(' ').trim();
    if (derived.isNotEmpty) return derived;
    return '';
  }

  String get derivedFirstName {
    if ((firstName ?? '').trim().isNotEmpty) return firstName!.trim();
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : '';
  }

  String get derivedLastName {
    if ((lastName ?? '').trim().isNotEmpty) return lastName!.trim();
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return '';
    return parts.skip(1).join(' ');
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'providerId': providerId,
      'providerType': providerType,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'bloodGroup': bloodGroup,
      'medicalInfo': medicalInfo,
    };
  }
}

class AccountFamilyMember {
  final String id;
  final String fullName;
  final String relationship;
  final String? gender;
  final int? ageYears;
  final String? bloodGroup;
  final Map<String, dynamic>? medicalInfo;

  AccountFamilyMember({
    required this.id,
    required this.fullName,
    required this.relationship,
    this.gender,
    this.ageYears,
    this.bloodGroup,
    this.medicalInfo,
  });

  factory AccountFamilyMember.fromJson(Map<String, dynamic> json) {
    return AccountFamilyMember(
      id: (json['id'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      relationship: (json['relationship'] ?? '').toString(),
      gender: json['gender']?.toString(),
      ageYears: (json['ageYears'] is num)
          ? (json['ageYears'] as num).toInt()
          : null,
      bloodGroup: _bloodGroupFromBackend(json['bloodGroup']?.toString()),
      medicalInfo: (json['medicalInfo'] is Map)
          ? (json['medicalInfo'] as Map).cast<String, dynamic>()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'relationship': relationship,
      'gender': gender,
      'ageYears': ageYears,
      'bloodGroup': bloodGroup,
      'medicalInfo': medicalInfo,
    };
  }
}

class AccountMedicalDocument {
  final String id;
  final String title;
  final String type;
  final String? issueDate;
  final String? fileUrl;

  AccountMedicalDocument({
    required this.id,
    required this.title,
    required this.type,
    this.issueDate,
    this.fileUrl,
  });

  factory AccountMedicalDocument.fromJson(Map<String, dynamic> json) {
    return AccountMedicalDocument(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      issueDate: json['issueDate']?.toString(),
      fileUrl: json['fileUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'issueDate': issueDate,
      'fileUrl': fileUrl,
    };
  }
}
