List<Map<String, dynamic>> createMockDoctors() {
  return [
    {
      'id': 'doc-1',
      'name': 'Dr. Sarah Mansour',
      'specialty': 'Médecin Généraliste',
      'rating': 4.8,
      'totalReviews': 127,
      'officeConsultationFee': 2500.0,
      'experienceYears': 12,
      'isOnline': true,
      'providerId': 'prov-1',
    },
    {
      'id': 'doc-2',
      'name': 'Dr. Karim Bensalem',
      'specialty': 'Pédiatre',
      'rating': 4.9,
      'totalReviews': 89,
      'officeConsultationFee': 3000.0,
      'experienceYears': 8,
      'isOnline': true,
      'providerId': 'prov-2',
    },
    {
      'id': 'doc-3',
      'name': 'Dr. Amina Hadj',
      'specialty': 'Kinésithérapeute',
      'rating': 4.7,
      'totalReviews': 54,
      'officeConsultationFee': 2000.0,
      'experienceYears': 6,
      'isOnline': false,
      'providerId': 'prov-3',
    },
    {
      'id': 'doc-4',
      'name': 'Dr. Redha Amrani',
      'specialty': 'Cardiologue',
      'rating': 4.9,
      'totalReviews': 203,
      'officeConsultationFee': 5000.0,
      'experienceYears': 15,
      'isOnline': true,
      'providerId': 'prov-4',
    },
    {
      'id': 'doc-5',
      'name': 'Dr. Nadia Cherif',
      'specialty': 'Dermatologue',
      'rating': 4.6,
      'totalReviews': 76,
      'officeConsultationFee': 3500.0,
      'experienceYears': 10,
      'isOnline': true,
      'providerId': 'prov-5',
    },
  ];
}

List<Map<String, dynamic>> createMockKines() {
  return [
    {
      'id': 'kine-1',
      'name': 'Dr. Amina Hadj',
      'specialty': 'Kinésithérapeute',
      'rating': 4.7,
      'totalReviews': 54,
      'officeConsultationFee': 2000.0,
      'experienceYears': 6,
      'isOnline': false,
      'providerId': 'prov-3',
    },
    {
      'id': 'kine-2',
      'name': 'Dr. Samir Boulenouar',
      'specialty': 'Kinésithérapeute du sport',
      'rating': 4.8,
      'totalReviews': 42,
      'officeConsultationFee': 2500.0,
      'experienceYears': 9,
      'isOnline': true,
      'providerId': 'prov-6',
    },
  ];
}

Map<String, dynamic> createMockDoctorProfile() {
  return {
    'id': 'prov-1',
    'name': 'Dr. Sarah Mansour',
    'email': 'sarah.mansour@omnicare.app',
    'specialty': 'Médecin Généraliste',
    'phoneNumber': '+213 555 11 22 33',
    'rating': 4.8,
    'totalReviews': 127,
    'officeConsultationFee': 2500.0,
    'experienceYears': 12,
    'isOnline': true,
    'address': 'Rue Didouche Mourad, Alger',
    'latitude': 36.7538,
    'longitude': 3.0588,
  };
}
