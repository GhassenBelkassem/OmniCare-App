import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../request_core/application/request_submission_controller.dart';
import '../../request_core/domain/request_vocabulary.dart';
import '../../request_history/presentation/patient_request_detail_screen.dart';

/// Step 6 / success — Request received.
///
/// Replaces the legacy submitted screen visually, not logically. The wording
/// is limited to what the backend actually guarantees after a 201/200: the
/// clinic has received the request and the patient will be notified on update.
/// It never claims a doctor was assigned, the clinic accepted, an appointment
/// was confirmed, or an ambulance was dispatched.
class RequestReceivedScreen extends StatelessWidget {
  const RequestReceivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final request = context.watch<RequestSubmissionController>();
    final status = request.result?.patientStatus;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF1FBF9A),
                  size: 60,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Request received',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D2939),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'The clinic has received your request.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF475467),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "You'll be notified when there is an update.",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF667085),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (status != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF1FBF9A).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F6F73),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              if (request.result != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PatientRequestDetailScreen(
                          requestId: request.result!.requestId,
                        ),
                      ),
                    ),
                    child: const Text('View request'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/home', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back to home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(PatientRequestStatus status) {
    if (status == PatientRequestStatus.requestReceived) {
      return 'Status: Request received';
    }
    return 'Status: ${status.wireValue.replaceAll('_', ' ').toLowerCase()}';
  }
}
