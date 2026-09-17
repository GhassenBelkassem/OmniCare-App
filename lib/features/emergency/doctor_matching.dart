import 'dart:async';

import 'package:flutter/foundation.dart';

class Doctor {
  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.avatar,
    required this.verified,
    required this.distance,
    required this.eta,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.tags,
    required this.description,
    required this.education,
    required this.certifications,
    required this.reviews,
    required this.phoneNumber,
    required this.backendDoctorId,
  });

  final int id;
  final String backendDoctorId;
  final String name;
  final String specialty;
  final String? avatar;
  final bool verified;
  final double distance;
  final int eta;
  final int price;
  final double rating;
  final int reviewCount;
  final List<String> tags;
  final String description;
  final List<String> education;
  final List<String> certifications;
  final List<DoctorReview> reviews;
  final String phoneNumber;
}

class DoctorReview {
  DoctorReview({
    required this.patientName,
    required this.rating,
    required this.comment,
    required this.date,
  });

  final String patientName;
  final double rating;
  final String comment;
  final String date;
}

enum DoctorMatchingStatus {
  searching,
  candidatesAvailable,
  waitingLonger,
  error,
}

sealed class DoctorMatchingEvent {
  const DoctorMatchingEvent();
}

class DoctorAccepted extends DoctorMatchingEvent {
  const DoctorAccepted(this.doctor);

  final Doctor doctor;
}

class DoctorMatchingWaitingLonger extends DoctorMatchingEvent {
  const DoctorMatchingWaitingLonger();
}

class DoctorMatchingFailed extends DoctorMatchingEvent {
  const DoctorMatchingFailed();
}

abstract interface class DoctorMatchingSource {
  Stream<DoctorMatchingEvent> get events;

  void start();

  void dispose();
}

/// Demo-only event source. A future backend event source can implement the
/// same contract without changing the matching screen.
class DemoDoctorMatchingSource implements DoctorMatchingSource {
  DemoDoctorMatchingSource({
    required this.doctors,
    this.acceptDelays = const [
      Duration(milliseconds: 1200),
      Duration(milliseconds: 2500),
      Duration(milliseconds: 4000),
    ],
    this.waitingAfter = const Duration(seconds: 6),
  });

  final List<Doctor> doctors;
  final List<Duration> acceptDelays;
  final Duration waitingAfter;
  final StreamController<DoctorMatchingEvent> _events =
      StreamController<DoctorMatchingEvent>.broadcast();
  final List<Timer> _timers = [];
  bool _disposed = false;

  @override
  Stream<DoctorMatchingEvent> get events => _events.stream;

  @override
  void start() {
    if (_disposed) return;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    _timers.add(
      Timer(waitingAfter, () {
        if (!_disposed) _events.add(const DoctorMatchingWaitingLonger());
      }),
    );

    for (var index = 0; index < doctors.length; index++) {
      final delay = index < acceptDelays.length
          ? acceptDelays[index]
          : acceptDelays.last;
      _timers.add(
        Timer(delay, () {
          if (!_disposed) _events.add(DoctorAccepted(doctors[index]));
        }),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _events.close();
  }
}

class DoctorMatchingController extends ChangeNotifier {
  DoctorMatchingController({required DoctorMatchingSource source})
    : _source = source {
    _subscription = _source.events.listen(_handleEvent);
  }

  final DoctorMatchingSource _source;
  late final StreamSubscription<DoctorMatchingEvent> _subscription;
  final List<Doctor> _candidates = [];
  DoctorMatchingStatus _status = DoctorMatchingStatus.searching;
  Doctor? _selectedDoctor;
  bool _selectionInProgress = false;
  bool _disposed = false;

  List<Doctor> get candidates => List.unmodifiable(_candidates);
  DoctorMatchingStatus get status => _status;
  Doctor? get selectedDoctor => _selectedDoctor;
  bool get selectionInProgress => _selectionInProgress;

  void start() {
    if (_disposed) return;
    _source.start();
  }

  void retry() {
    if (_disposed) return;
    _candidates.clear();
    _selectedDoctor = null;
    _selectionInProgress = false;
    _status = DoctorMatchingStatus.searching;
    notifyListeners();
    _source.start();
  }

  bool selectDoctor(Doctor doctor) {
    if (_disposed || _selectionInProgress || !_candidates.contains(doctor)) {
      return false;
    }
    _selectionInProgress = true;
    _selectedDoctor = doctor;
    notifyListeners();
    return true;
  }

  void _handleEvent(DoctorMatchingEvent event) {
    if (_disposed) return;
    switch (event) {
      case DoctorAccepted(:final doctor):
        if (_candidates.any(
          (candidate) => candidate.backendDoctorId == doctor.backendDoctorId,
        )) {
          return;
        }
        _candidates.add(doctor);
        _status = DoctorMatchingStatus.candidatesAvailable;
      case DoctorMatchingWaitingLonger():
        if (_candidates.isEmpty) _status = DoctorMatchingStatus.waitingLonger;
      case DoctorMatchingFailed():
        _status = DoctorMatchingStatus.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    _source.dispose();
    super.dispose();
  }
}

List<Doctor> createDemoUrgentDoctors() {
  return [
    Doctor(
      id: 1,
      backendDoctorId: 'doc-1',
      name: 'Dr. Sami Ben Ali',
      specialty: 'Médecin généraliste',
      avatar: null,
      verified: true,
      distance: 2.4,
      eta: 8,
      price: 100,
      rating: 4.8,
      reviewCount: 142,
      tags: ['ECG Portable', 'Urgences', 'Arabe/Français'],
      description:
          'Médecin généraliste expérimenté spécialisé dans les soins d’urgence à domicile.',
      education: [
        'Doctorat en Médecine - Faculté de Médecine de Tunis (2008)',
        'Résidence en Médecine Générale - CHU La Rabta (2008-2012)',
      ],
      certifications: [
        'Certification en Médecine d’Urgence',
        'Formation ECG et Cardiologie',
      ],
      reviews: [
        DoctorReview(
          patientName: 'Ahmed K.',
          rating: 5.0,
          comment: 'Excellent médecin, très professionnel et à l’écoute.',
          date: 'Il y a 2 semaines',
        ),
      ],
      phoneNumber: '+216 98 123 456',
    ),
    Doctor(
      id: 2,
      backendDoctorId: 'doc-2',
      name: 'Dr. Amira Mansouri',
      specialty: 'Médecin généraliste',
      avatar: null,
      verified: true,
      distance: 3.1,
      eta: 11,
      price: 150,
      rating: 4.9,
      reviewCount: 203,
      tags: ['Soins à domicile', 'Pédiatrie'],
      description:
          'Médecin généraliste avec une approche attentive pour les soins urgents à domicile.',
      education: [
        'Doctorat en Médecine - Faculté de Médecine de Sousse (2010)',
        'Formation en Médecine Générale - CHU Farhat Hached (2010-2014)',
      ],
      certifications: ['Certification en Pédiatrie d’Urgence'],
      reviews: [
        DoctorReview(
          patientName: 'Leila B.',
          rating: 5.0,
          comment: 'Très professionnelle et rassurante.',
          date: 'Il y a 1 semaine',
        ),
      ],
      phoneNumber: '+216 22 456 789',
    ),
    Doctor(
      id: 3,
      backendDoctorId: 'doc-3',
      name: 'Dr. Youssef Gharbi',
      specialty: 'Médecin généraliste',
      avatar: null,
      verified: true,
      distance: 4.0,
      eta: 14,
      price: 80,
      rating: 4.7,
      reviewCount: 95,
      tags: ['Maladies chroniques', 'Diabète'],
      description:
          'Médecin généraliste disponible pour les interventions urgentes à domicile.',
      education: [
        'Doctorat en Médecine - Faculté de Médecine de Monastir (2012)',
        'Formation en Médecine Interne - CHU Monastir (2012-2016)',
      ],
      certifications: ['Certification en Diabétologie'],
      reviews: [
        DoctorReview(
          patientName: 'Nadia T.',
          rating: 4.5,
          comment: 'Médecin compétent et disponible.',
          date: 'Il y a 2 semaines',
        ),
      ],
      phoneNumber: '+216 55 789 123',
    ),
  ];
}
