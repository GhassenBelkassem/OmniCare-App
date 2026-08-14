import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../request_core/application/request_submission_controller.dart';
import '../../request_core/domain/request_vocabulary.dart';
import 'pickup_screen.dart';
import 'review_screen.dart';

/// Step 3 — Situation.
///
/// The three backend wire values, chosen explicitly by the patient. Urgency is
/// never inferred from age, history, symptoms, location or anything else — the
/// patient decides. Selecting AMBULANCE means the patient is requesting
/// transport assistance; it does not mean an ambulance has been dispatched.
class SituationScreen extends StatelessWidget {
  const SituationScreen({super.key});

  static const List<_SituationOption> _options = [
    _SituationOption(
      situation: RequestSituation.appointment,
      title: 'Appointment',
      description: 'Can go to the clinic and the situation is not urgent.',
      icon: Icons.event_available_outlined,
    ),
    _SituationOption(
      situation: RequestSituation.urgent,
      title: 'Urgent',
      description: 'Needs care quickly and can still get to the clinic.',
      icon: Icons.priority_high_outlined,
    ),
    _SituationOption(
      situation: RequestSituation.ambulance,
      title: 'Transport assistance',
      description: 'Needs urgent care and requires transport assistance.',
      icon: Icons.emergency_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final request = context.watch<RequestSubmissionController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'What do you need?',
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
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final option = _options[index];
                final selected = request.selectedSituation == option.situation;
                return _SituationTile(
                  option: option,
                  selected: selected,
                  onTap: () {
                    context
                        .read<RequestSubmissionController>()
                        .selectSituation(option.situation);
                  },
                );
              },
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
                  onPressed: request.selectedSituation == null
                      ? null
                      : () {
                          final next = request.selectedSituation ==
                                  RequestSituation.ambulance
                              ? const PickupScreen()
                              : const ReviewScreen();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => next),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD0D5DD),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SituationTile extends StatelessWidget {
  const _SituationTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _SituationOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : Colors.grey.withOpacity(0.18),
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1FBF9A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(option.icon, color: const Color(0xFF1FBF9A)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D2939),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF667085),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: Color(0xFF1FBF9A)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SituationOption {
  const _SituationOption({
    required this.situation,
    required this.title,
    required this.description,
    required this.icon,
  });

  final RequestSituation situation;
  final String title;
  final String description;
  final IconData icon;
}
