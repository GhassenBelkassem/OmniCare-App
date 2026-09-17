import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../models/patient_passport_view_models.dart';
import 'passport_card.dart';

class PassportIdentityCard extends StatelessWidget {
  final PatientPassportViewData data;

  const PassportIdentityCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return PassportCard(
      color: OmniColors.mintSoft,
      border: Border.all(color: OmniColors.freshMint.withValues(alpha: 0.18)),
      child: Column(
        children: [
          const PassportSectionHeading(
            icon: Icons.badge_outlined,
            title: 'Identité du passeport',
            subtitle: 'Coordonnées et identifiant OmniCare',
            iconColor: OmniColors.deepTeal,
            iconBackground: Colors.white,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final qrSize = constraints.maxWidth < 380 ? 92.0 : 108.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _InfoRow(label: 'Nom complet', value: data.name),
                        _InfoRow(label: 'Téléphone', value: data.phone),
                        _InfoRow(label: 'E-mail', value: data.email),
                        _InfoRow(label: 'ID OMNICARE', value: data.omniCareId),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: OmniColors.freshMint.withValues(alpha: 0.25),
                      ),
                    ),
                    child: QrImageView(
                      data: 'OMNICARE-PASSPORT-${data.omniCareId}',
                      version: QrVersions.auto,
                      size: qrSize,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: OmniColors.deepTeal,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: OmniColors.primaryAction,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const PassportPrivacyNote(),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x3370BCAA))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: OmniColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniColors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
