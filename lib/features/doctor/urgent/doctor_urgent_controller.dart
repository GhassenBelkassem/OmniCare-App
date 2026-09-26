import 'dart:async';

import 'package:flutter/material.dart';

enum DoctorUrgentState {
  offline,
  available,
  offerReceived,
  acceptedWaitingPatient,
  selected,
  enRoute,
  arrived,
}

class DoctorUrgentRequest {
  const DoctorUrgentRequest({
    required this.id,
    required this.age,
    required this.complaint,
    required this.symptoms,
    required this.area,
    required this.distance,
    required this.eta,
    this.patientName,
    this.address,
  });
  final String id;
  final int age;
  final String complaint;
  final List<String> symptoms;
  final String area;
  final String distance;
  final String eta;
  final String? patientName;
  final String? address;
  static const demo = DoctorUrgentRequest(
    id: 'OMN-2026-1847',
    age: 45,
    complaint: 'Douleur thoracique importante',
    symptoms: ['Difficulté respiratoire', 'Nausée'],
    area: 'Tunis centre',
    distance: '1,8 km',
    eta: '≈ 6 min',
    patientName: 'Amina Chaari',
    address: '15 Avenue Habib Bourguiba\nTunis',
  );
}

class DoctorUrgentController extends ChangeNotifier {
  DoctorUrgentController({this.offerDuration = const Duration(seconds: 45)});

  final Duration offerDuration;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  DoctorUrgentState _state = DoctorUrgentState.offline;
  DoctorUrgentState get state => _state;
  DoctorUrgentRequest get request => DoctorUrgentRequest.demo;
  bool get identityRevealed => _state.index >= DoctorUrgentState.selected.index;
  int get remainingSeconds => _remainingSeconds;
  String get countdownLabel =>
      '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}';
  void goOnline() => _set(DoctorUrgentState.available);
  void goOffline() => _set(DoctorUrgentState.offline);
  void showOffer() {
    if (_state == DoctorUrgentState.available) {
      _remainingSeconds = offerDuration.inSeconds;
      _set(DoctorUrgentState.offerReceived);
      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => tick(),
      );
    }
  }

  void decline() {
    if (_state == DoctorUrgentState.offerReceived) {
      _set(DoctorUrgentState.available);
    }
  }

  void accept() {
    if (_state == DoctorUrgentState.offerReceived) {
      _set(DoctorUrgentState.acceptedWaitingPatient);
    }
  }

  void simulateSelection() {
    if (_state == DoctorUrgentState.acceptedWaitingPatient) {
      _set(DoctorUrgentState.selected);
    }
  }

  void startRoute() {
    if (_state == DoctorUrgentState.selected) {
      _set(DoctorUrgentState.enRoute);
    }
  }

  void arrive() {
    if (_state == DoctorUrgentState.enRoute) {
      _set(DoctorUrgentState.arrived);
    }
  }

  void expireOffer() {
    if (_state == DoctorUrgentState.offerReceived) {
      _set(DoctorUrgentState.available);
    }
  }

  void tick() {
    if (_state != DoctorUrgentState.offerReceived) return;
    if (_remainingSeconds <= 1) {
      expireOffer();
      return;
    }
    _remainingSeconds -= 1;
    notifyListeners();
  }

  void _set(DoctorUrgentState value) {
    if (value != DoctorUrgentState.offerReceived) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      if (value == DoctorUrgentState.available) _remainingSeconds = 0;
    }
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
