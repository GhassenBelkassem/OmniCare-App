import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/family_provider.dart';
import '../../patient_clinic/application/patient_clinic_directory_controller.dart';
import '../../request_core/application/request_submission_controller.dart';
import '../../request_core/domain/pickup_location.dart';
import '../../request_core/domain/request_vocabulary.dart';
import 'pickup_screen.dart';
import 'situation_screen.dart';
import 'who_needs_care_screen.dart';
import '../../patient_clinic/presentation/clinic_directory_screen.dart';

/// Step 5 — Review.
///
/// Shows the typed, fully described request. No `Map<String, dynamic>` is
/// passed between screens: every value is read from the
/// [RequestSubmissionController] (and the clinic detail from
/// [PatientClinicDirectoryController]). Each section offers Change, which
/// returns to the relevant step; after the first submission attempt a Change
/// triggers a new logical request id (handled by the controller).
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  @override
  void initState() {
    super.initState();
    final request = context.read<RequestSubmissionController>();
    final directory = context.read<PatientClinicDirectoryController>();
    final clinicId = request.selectedClinicId;
    if (clinicId != null && directory.detail?.clinicId != clinicId) {
      directory.fetchDetail(clinicId);
    }
  }

  void _send(BuildContext context) async {
    final request = context.read<RequestSubmissionController>();
    await request.submit();
    if (!mounted) return;
    if (request.hasSucceeded) {
      Navigator.of(context).pushReplacementNamed('/m05/received');
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = context.watch<RequestSubmissionController>();
    final directory = context.watch<PatientClinicDirectoryController>();

    final clinic = directory.detail;
    final situation = request.selectedSituation;
    final clinicLocation = clinic == null
        ? ''
        : <String>[
            if (clinic.city != null) clinic.city!,
            if (clinic.governorate != null) clinic.governorate!,
          ].join(', ');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Review request',
          style: TextStyle(
            color: Color(0xFF1D2939),
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: const BackButton(color: Color(0xFF1D2939)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Section(
                  label: 'Patient',
                  value: _patientLabel(request),
                  onChanged: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WhoNeedsCareScreen(),
                    ),
                  ),
                  child: Text(
                    _patientLabel(request),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1D2939),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  label: 'Clinic',
                  value: clinic?.displayName ?? 'Selected clinic',
                  onChanged: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ClinicDirectoryScreen(),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinic?.displayName ?? 'Selected clinic',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1D2939),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (clinicLocation.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            clinicLocation,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  label: 'Situation',
                  value: _situationLabel(situation),
                  onChanged: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SituationScreen()),
                  ),
                  child: Text(
                    _situationLabel(situation),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1D2939),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (situation == RequestSituation.ambulance) ...[
                  const SizedBox(height: 12),
                  _Section(
                    label: 'Pickup location',
                    value: _pickupLabel(request.selectedPickup),
                    onChanged: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PickupScreen()),
                    ),
                    child: Text(
                      _pickupLabel(request.selectedPickup),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1D2939),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (request.failure != null)
                  _ErrorBanner(
                    message: request.failure!.message,
                    canRetry: request.canRetry,
                    onRetry: () => _send(context),
                    onStartOver: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/m05/request',
                        (route) => route.isFirst,
                      );
                    },
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: request.canSubmit && !request.isSubmitting
                      ? () => _send(context)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD0D5DD),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: request.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Send Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _patientLabel(RequestSubmissionController request) {
    if (request.subject.isSelf) return 'Me';
    final memberId = request.subject.familyMemberId;
    if (memberId != null) {
      final members = context.read<FamilyProvider>().members;
      for (final member in members) {
        if (member.id == memberId) return member.fullName;
      }
      return 'Family member';
    }
    return 'Me';
  }

  String _situationLabel(RequestSituation? situation) {
    return switch (situation) {
      RequestSituation.appointment => 'Appointment',
      RequestSituation.urgent => 'Urgent',
      RequestSituation.ambulance => 'Transport assistance',
      _ => 'Not selected',
    };
  }

  String _pickupLabel(PickupLocationSelection? pickup) {
    if (pickup == null) return 'Not selected';
    return switch (pickup.source) {
      PickupLocationSource.deviceGps => 'Current device location',
      PickupLocationSource.mapSelection => 'Selected location on map',
      PickupLocationSource.manualAddress =>
        pickup.postalAddress != null
            ? _addressLabel(pickup.postalAddress!)
            : 'Manual address',
      _ => 'Pickup location',
    };
  }

  String _addressLabel(PostalAddress address) {
    final parts = [
      address.addressLine,
      address.addressDetails,
      address.city,
      address.governorate,
    ].where((p) => p != null && p!.isNotEmpty).join(', ');
    return parts.isEmpty ? 'Manual address' : parts;
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.child,
  });

  final String label;
  final String value;
  final VoidCallback onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF98A2B3),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
          TextButton(onPressed: onChanged, child: const Text('Change')),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onStartOver,
  });

  final String message;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD92D20).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: Color(0xFFD92D20), fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (canRetry)
            TextButton(onPressed: onRetry, child: const Text('Retry'))
          else
            TextButton(
              onPressed: onStartOver,
              child: const Text('Start a new request'),
            ),
        ],
      ),
    );
  }
}
