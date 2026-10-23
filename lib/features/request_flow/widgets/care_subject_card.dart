import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';

/// Shared presentation for a person who can be selected as the care subject.
///
/// The profile-tile layout is used by the approved clinic/doctor selector. The
/// compact layout keeps the same avatar, selection, and typography language for
/// flows that also need an inline form or a longer list of people.
class CareSubjectCard extends StatelessWidget {
  const CareSubjectCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.avatarId,
    this.photoUrl,
    this.isSelf = false,
    this.fallbackIcon,
    this.trailingLabel,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? avatarId;
  final String? photoUrl;
  final bool isSelf;
  final IconData? fallbackIcon;
  final String? trailingLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Keep the machine-readable status wording used by the approved selector
    // tests and assistive technology clients.
    final semanticLabel = selected
        ? '$title, $subtitle, selected'
        : '$title, $subtitle, not selected';

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(OmniRadii.card),
          child: compact ? _buildCompact(context) : _buildProfileTile(context),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? OmniColors.mintSoft : OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(
          color: selected ? OmniColors.freshMint : OmniColors.borderLight,
          width: selected ? 1.8 : 1,
        ),
        boxShadow: const [OmniColors.shadowSm],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CareSubjectAvatar(
              id: avatarId,
              photoUrl: photoUrl,
              isSelf: isSelf,
              fallbackIcon: fallbackIcon,
              size: 56,
            ),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.3,
                    color: OmniColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trailingLabel != null) ...[
            const SizedBox(width: OmniSpacing.sm),
            Text(
              trailingLabel!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OmniColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(width: OmniSpacing.sm),
          _SelectionIndicator(selected: selected),
        ],
      ),
    );
  }

  Widget _buildProfileTile(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected ? OmniColors.freshMint : Colors.transparent,
                  width: 2.2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: CareSubjectAvatar(
                  id: avatarId,
                  photoUrl: photoUrl,
                  isSelf: isSelf,
                  fallbackIcon: fallbackIcon,
                  size: 120,
                ),
              ),
            ),
            if (selected)
              const Positioned(top: -2, right: -2, child: _SelectionBadge()),
          ],
        ),
        const SizedBox(height: OmniSpacing.sm),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 15,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: OmniColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            height: 1.3,
            color: OmniColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class CareSubjectAvatar extends StatelessWidget {
  const CareSubjectAvatar({
    super.key,
    this.id,
    this.photoUrl,
    this.isSelf = false,
    this.fallbackIcon,
    required this.size,
  });

  final String? id;
  final String? photoUrl;
  final bool isSelf;
  final IconData? fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl?.trim();
    if (photo != null && photo.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: photo,
        fit: BoxFit.cover,
        placeholder: (_, _) => _fallback(context),
        errorWidget: (_, _, _) => _fallback(context),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    if (fallbackIcon != null) {
      return Container(
        color: OmniColors.slateSoft,
        alignment: Alignment.center,
        child: Icon(
          fallbackIcon,
          color: OmniColors.slateBlue,
          size: size * 0.42,
        ),
      );
    }

    final assetIndex = id == null ? 0 : _stableIndex(id!, 12);
    final asset =
        'assets/images/avatars/lorelei/avatar_${(assetIndex + 1).toString().padLeft(2, '0')}.png';
    final background = isSelf ? OmniColors.slateSoft : OmniColors.violetSoft;
    final foreground = isSelf ? OmniColors.slateBlue : OmniColors.violet;
    final label = isSelf ? 'M' : _initials(id ?? '');

    return Image.asset(
      asset,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: background,
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: size * 0.27,
            height: 1,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: selected ? OmniColors.freshMint : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? OmniColors.freshMint : OmniColors.borderStrong,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: 16,
              color: OmniColors.deepTealActive,
            )
          : null,
    );
  }
}

class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: OmniColors.freshMint,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.check_rounded,
        size: 16,
        color: OmniColors.deepTealActive,
      ),
    );
  }
}

int _stableIndex(String id, int modulus) {
  var hash = 0;
  for (final codeUnit in id.codeUnits) {
    hash = ((hash * 31) + codeUnit) & 0x7fffffff;
  }
  return hash % modulus;
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
