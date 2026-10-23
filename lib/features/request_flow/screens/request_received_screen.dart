import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../../request_core/application/request_submission_controller.dart';
import '../../request_history/presentation/patient_request_detail_screen.dart';

/// Post-submission success screen.
///
/// Reassures the patient, reminds them which clinic received the request,
/// explains the immediate next step, and offers View request + quiet back-home.
class RequestReceivedScreen extends StatelessWidget {
  const RequestReceivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final request = context.watch<RequestSubmissionController>();
    final result = request.result;

    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.pageHorizontal,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _SuccessVisual(),
              const SizedBox(height: 28),
              Text(
                'Request received',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: OmniColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'The clinic has received your request.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: OmniColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "We'll notify you when there is an update.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _WhatHappensNext(),
              const Spacer(flex: 3),
              if (result != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PatientRequestDetailScreen(
                          requestId: result.requestId,
                        ),
                      ),
                    ),
                    child: const Text('View request'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/home',
                        (route) => false,
                      );
                    },
                    child: const Text('Back to home'),
                  ),
                ),
              ],
              const SizedBox(height: OmniSpacing.pageVertical),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessVisual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: OmniColors.mintSoft,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_circle,
        color: OmniColors.primaryAction,
        size: 36,
      ),
    );
  }
}

class _WhatHappensNext extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happens next',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: OmniColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _NextStep(
            step: '1',
            title: 'Clinic review',
            description: 'The clinic reviews your request.',
          ),
          const SizedBox(height: 8),
          _NextStep(
            step: '2',
            title: 'Stay updated',
            description: "We'll notify you when something changes.",
          ),
        ],
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.step,
    required this.title,
    required this.description,
  });

  final String step;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: OmniColors.primaryAction,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: OmniColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
