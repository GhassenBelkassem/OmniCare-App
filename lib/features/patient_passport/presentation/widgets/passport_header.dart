import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../models/patient_passport_view_models.dart';

class PassportHeader extends StatelessWidget {
  final PassportFamilyMember selectedMember;
  final VoidCallback onSelectPassport;

  /// The edit pencil (G2.1-A2); hidden when null.
  final VoidCallback? onEdit;
  final VoidCallback onShare;

  const PassportHeader({
    super.key,
    required this.selectedMember,
    required this.onSelectPassport,
    this.onEdit,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Changer de passeport, ${selectedMember.name}',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onSelectPassport,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Passeport médical · ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: OmniColors.textPrimary,
                            ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        selectedMember.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: OmniColors.deepTeal,
                            ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: OmniColors.slateBlue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onEdit case final onEdit?) ...[
          _HeaderAction(
            icon: Icons.edit_outlined,
            label: 'Modifier le passeport',
            onPressed: onEdit,
          ),
          const SizedBox(width: 8),
        ],
        _HeaderAction(
          icon: Icons.share_outlined,
          label: 'Partager le passeport',
          onPressed: onShare,
          backgroundColor: OmniColors.mintSoft,
          iconColor: OmniColors.primaryAction,
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;

  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: iconColor ?? OmniColors.slateBlue,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: backgroundColor ?? Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: backgroundColor == null
                ? const BorderSide(color: OmniColors.borderLight)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
