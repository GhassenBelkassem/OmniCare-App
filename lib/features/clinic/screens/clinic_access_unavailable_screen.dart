import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../application/clinic_context_controller.dart';
import '../widgets/clinic_widgets.dart';

/// Safe terminal screen for every clinic access problem: no clinic access, no
/// active membership, a mapped ProblemDetail or a retryable network failure.
///
/// It never renders backend detail, request IDs, clinic IDs or internal error
/// codes.
class ClinicAccessUnavailableScreen extends StatelessWidget {
  const ClinicAccessUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicContextController>();
    final failure = clinic.failure;
    final retryable = failure?.retryable ?? true;
    final message =
        failure?.message ??
        'You do not have an active clinic membership right now.';

    return ClinicPageScaffold(
      title: 'Clinic access unavailable',
      subtitle: message,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ClinicPalette.warningSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.info_outline,
          color: ClinicPalette.warning,
          size: 22,
        ),
      ),
      children: [
        const ClinicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClinicSectionTitle('What you can do'),
              SizedBox(height: 10),
              _AdviceLine(
                'Ask your clinic administrator to confirm your membership.',
              ),
              _AdviceLine('Try again once your access has been updated.'),
              _AdviceLine('Sign out to use another account.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (retryable) ...[
          ClinicPrimaryButton(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: clinic.isLoading ? null : () => clinic.retry(),
          ),
          const SizedBox(height: 10),
        ],
        ClinicSecondaryButton(
          label: 'Sign out',
          icon: Icons.logout,
          onPressed: () => context.read<AuthController>().logout(),
        ),
      ],
    );
  }
}

class _AdviceLine extends StatelessWidget {
  const _AdviceLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_outline,
              size: 16,
              color: ClinicPalette.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: clinicTextStyle(
                fontSize: 13,
                color: ClinicPalette.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
