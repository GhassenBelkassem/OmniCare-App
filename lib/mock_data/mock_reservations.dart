List<Map<String, dynamic>> createMockReservationRequests() {
  return [
    {
      'id': 'res-1',
      'providerId': 'prov-1',
      'providerName': 'Dr. Sarah Mansour',
      'providerType': 'doctor',
      'status': 'PENDING',
      'searchStartDate': '2026-07-10',
      'searchEndDate': '2026-07-12',
      'reason': 'Consultation générale',
      'createdAt': '2026-07-08T14:30:00Z',
      'intents': [
        {'date': '2026-07-10', 'timeWindow': 'MORNING'},
        {'date': '2026-07-11', 'timeWindow': 'AFTERNOON'},
        {'date': '2026-07-12', 'timeWindow': 'MORNING'},
      ],
    },
  ];
}

Map<String, dynamic> createMockCreatedReservation() {
  return {
    'id': 'res-2',
    'status': 'PENDING',
    'message': 'Demande de rendez-vous envoyée avec succès',
  };
}
