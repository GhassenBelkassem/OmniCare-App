import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_message.dart';
import '../../l10n/omni_localizations.dart';

const _ink = Color(0xFF111827);
const _muted = Color(0xFF667085);
const _teal = Color(0xFF087A65);
const _mint = Color(0xFF1FBF9A);
const _paleMint = Color(0xFFE8F8F3);
const _surface = Color(0xFFFFFFFF);
const _line = Color(0xFFE1E7E5);
const _danger = Color(0xFFD92D20);

typedef PersonalInformationChanged =
    Future<void> Function({
      required String firstName,
      required String lastName,
      required DateTime dateOfBirth,
      required String gender,
    });

typedef NotificationPreferencesChanged =
    Future<void> Function({
      bool? medications,
      bool? appointments,
      bool? passport,
    });

typedef AvatarSourceSelected = Future<void> Function(ImageSource source);

class PatientProfileIdentity {
  const PatientProfileIdentity({
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.phoneNumber,
    required this.phoneVerified,
    required this.email,
    required this.emailVerified,
    this.avatarUrl,
    this.dateOfBirth,
    this.gender,
  });

  final String firstName;
  final String lastName;
  final String displayName;
  final String phoneNumber;
  final bool phoneVerified;
  final String email;
  final bool emailVerified;
  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final String? gender;
}

class PatientProfileFamilyMember {
  const PatientProfileFamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
    this.avatarUrl,
    this.graduated = false,
  });

  final String id;
  final String name;
  final String relationship;
  final String? avatarUrl;
  final bool graduated;
}

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({
    super.key,
    required this.identity,
    required this.familyMembers,
    required this.onLogout,
    required this.isLoggingOut,
    required this.isSaving,
    required this.isAvatarUploading,
    required this.onAvatarSourceSelected,
    required this.onAvatarRemove,
    required this.onPersonalInformationChanged,
    required this.onLanguageChanged,
    required this.onNotificationPreferencesChanged,
    required this.onOpenAccountSecurity,
    required this.onOpenDevices,
    required this.onOpenLoginHistory,
    this.onOpenAppointments,
    this.onOpenRequests,
    this.onAddFamilyMember,
    this.onEditFamilyMember,
    this.onDeactivateFamilyMember,
    this.onRetryFamily,
    this.familyErrorMessage,
    this.familyIsLoading = false,
    this.errorMessage,
    this.onRetry,
    this.avatarUploadProgress,
    this.avatarErrorMessage,
    this.onAvatarRetry,
    this.onAvatarErrorDismiss,
    this.preferredLanguage = 'fr',
    this.notificationMedications = true,
    this.notificationAppointments = true,
    this.notificationPassport = true,
  });

  final PatientProfileIdentity identity;
  final List<PatientProfileFamilyMember> familyMembers;
  final Future<void> Function() onLogout;
  final VoidCallback? onAddFamilyMember;
  final Future<void> Function(String id)? onEditFamilyMember;
  final Future<void> Function(String id)? onDeactivateFamilyMember;
  final VoidCallback? onRetryFamily;
  final String? familyErrorMessage;
  final bool familyIsLoading;
  final bool isLoggingOut;
  final bool isSaving;
  final bool isAvatarUploading;
  final double? avatarUploadProgress;
  final String? avatarErrorMessage;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final AvatarSourceSelected onAvatarSourceSelected;
  final Future<void> Function() onAvatarRemove;
  final Future<void> Function()? onAvatarRetry;
  final VoidCallback? onAvatarErrorDismiss;
  final PersonalInformationChanged onPersonalInformationChanged;
  final Future<void> Function(String language) onLanguageChanged;
  final NotificationPreferencesChanged onNotificationPreferencesChanged;
  final VoidCallback onOpenAccountSecurity;
  final VoidCallback onOpenDevices;
  final VoidCallback onOpenLoginHistory;
  final VoidCallback? onOpenAppointments;
  final VoidCallback? onOpenRequests;
  final String preferredLanguage;
  final bool notificationMedications;
  final bool notificationAppointments;
  final bool notificationPassport;

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  bool get _isBusy => widget.isSaving || widget.isAvatarUploading;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('patient-profile'),
      padding: const EdgeInsets.only(bottom: 112),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isBusy) ...[
                  LinearProgressIndicator(
                    value: widget.isAvatarUploading
                        ? widget.avatarUploadProgress
                        : null,
                    minHeight: 3,
                    color: _mint,
                    backgroundColor: _paleMint,
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Profil', style: _text(size: 28, weight: FontWeight.w800)),
                const SizedBox(height: 18),
                _buildIdentityCard(),
                if ((widget.errorMessage ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _ProfileErrorBanner(
                    message: widget.errorMessage!.trim(),
                    onRetry: widget.onRetry,
                  ),
                ],
                if ((widget.avatarErrorMessage ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _AvatarErrorBanner(
                    message: widget.avatarErrorMessage!.trim(),
                    onRetry: widget.onAvatarRetry == null ? null : _retryAvatar,
                    onDismiss: widget.onAvatarErrorDismiss,
                  ),
                ],
                const SizedBox(height: 28),
                const _SectionLabel('ACTIVITÉ'),
                const SizedBox(height: 10),
                _ProfileGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.calendar_month_outlined,
                      iconColor: _teal,
                      iconBackground: _paleMint,
                      title: 'Mes rendez-vous',
                      subtitle: 'Prochains rendez-vous et historique',
                      onTap: _isBusy ? null : widget.onOpenAppointments,
                    ),
                    _SettingsTile(
                      icon: Icons.receipt_long_outlined,
                      iconColor: const Color(0xFF175CD3),
                      iconBackground: const Color(0xFFEFF4FF),
                      title: 'Mes demandes',
                      subtitle: 'Suivi de vos demandes',
                      onTap: _isBusy ? null : widget.onOpenRequests,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _SectionLabel('MON COMPTE'),
                const SizedBox(height: 10),
                _ProfileGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.person_outline_rounded,
                      iconColor: _teal,
                      iconBackground: _paleMint,
                      title: 'Informations personnelles',
                      subtitle: 'Identité et coordonnées',
                      onTap: _isBusy ? null : _showPersonalInformation,
                    ),
                    _FamilyTile(
                      members: widget.familyMembers,
                      onTap: _isBusy ? null : _showFamily,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('PRÉFÉRENCES'),
                const SizedBox(height: 10),
                _ProfileGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.language_rounded,
                      iconColor: const Color(0xFF175CD3),
                      iconBackground: const Color(0xFFEFF4FF),
                      title: 'Langue de l’application',
                      trailingText: _languageName(widget.preferredLanguage),
                      onTap: _isBusy ? null : _showLanguagePicker,
                    ),
                    _SettingsTile(
                      icon: Icons.notifications_none_rounded,
                      iconColor: const Color(0xFFB54708),
                      iconBackground: const Color(0xFFFFFAEB),
                      title: 'Notifications',
                      subtitle: 'Rappels et activité du compte',
                      onTap: _isBusy ? null : _showNotificationPreferences,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('SÉCURITÉ ET CONFIDENTIALITÉ'),
                const SizedBox(height: 10),
                _ProfileGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.shield_outlined,
                      iconColor: const Color(0xFF6941C6),
                      iconBackground: const Color(0xFFF4F3FF),
                      title: 'Sécurité du compte',
                      subtitle: 'Téléphone, mot de passe et verrouillage',
                      onTap: _isBusy ? null : widget.onOpenAccountSecurity,
                    ),
                    _SettingsTile(
                      icon: Icons.devices_outlined,
                      iconColor: const Color(0xFF026AA2),
                      iconBackground: const Color(0xFFF0F9FF),
                      title: 'Mes appareils',
                      subtitle: 'Sessions et appareils autorisés',
                      onTap: _isBusy ? null : widget.onOpenDevices,
                    ),
                    _SettingsTile(
                      icon: Icons.history_rounded,
                      iconColor: const Color(0xFF344054),
                      iconBackground: const Color(0xFFF2F4F7),
                      title: 'Historique de connexion',
                      onTap: _isBusy ? null : widget.onOpenLoginHistory,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('ASSISTANCE'),
                const SizedBox(height: 10),
                _ProfileGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.help_outline_rounded,
                      iconColor: _teal,
                      iconBackground: _paleMint,
                      title: 'Aide et support',
                      onTap: _isBusy ? null : _showSupport,
                    ),
                    _SettingsTile(
                      icon: Icons.policy_outlined,
                      iconColor: const Color(0xFF344054),
                      iconBackground: const Color(0xFFF2F4F7),
                      title: 'Confidentialité et conditions',
                      onTap: _isBusy ? null : _showPrivacy,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildAccountActions(),
                const SizedBox(height: 18),
                Text(
                  'OmniCare · Version 1.0.0',
                  textAlign: TextAlign.center,
                  style: _text(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: const Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityCard() {
    final identity = widget.identity;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF073E3C),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF073E3C).withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isBusy ? null : _showAvatarActions,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _ProfileAvatar(
                  name: identity.displayName,
                  avatarUrl: identity.avatarUrl,
                  size: 72,
                ),
                if (widget.isAvatarUploading)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF073E3C).withValues(alpha: 0.62),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            value: widget.avatarUploadProgress,
                            strokeWidth: 3,
                            color: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _mint,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF073E3C),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    size: 19,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: Color(0xFF6CE9C4),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        identity.phoneVerified || identity.emailVerified
                            ? 'Compte vérifié'
                            : 'Vérification requise',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(
                          size: 12,
                          weight: FontWeight.w700,
                          color: const Color(0xFFB7E9DD),
                        ),
                      ),
                    ),
                  ],
                ),
                if (identity.phoneNumber.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    identity.phoneNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Modifier le profil',
            child: Material(
              color: Colors.white.withValues(alpha: 0.12),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _isBusy ? null : _showPersonalInformation,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: widget.isLoggingOut || _isBusy ? null : _confirmLogout,
            icon: widget.isLoggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _danger,
                    ),
                  )
                : const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Se déconnecter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _danger,
              side: const BorderSide(color: Color(0xFFFDA29B)),
              backgroundColor: const Color(0xFFFFFBFA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: _text(size: 14, weight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _isBusy ? null : _confirmDeleteAccount,
          style: TextButton.styleFrom(
            foregroundColor: _danger,
            textStyle: _text(size: 12.5, weight: FontWeight.w700),
          ),
          child: const Text('Supprimer mon compte'),
        ),
      ],
    );
  }

  Future<void> _showAvatarActions() {
    final hasAvatar = (widget.identity.avatarUrl ?? '').trim().isNotEmpty;
    return _showSheet(
      title: 'Photo de profil',
      child: Column(
        children: [
          _ProfileAvatar(
            name: widget.identity.displayName,
            avatarUrl: widget.identity.avatarUrl,
            size: 96,
          ),
          const SizedBox(height: 22),
          _AvatarActionTile(
            icon: Icons.photo_library_outlined,
            title: 'Choisir dans la photothèque',
            onTap: () => _startAvatarUpload(ImageSource.gallery),
          ),
          const SizedBox(height: 10),
          _AvatarActionTile(
            icon: Icons.camera_alt_outlined,
            title: 'Prendre une photo',
            onTap: () => _startAvatarUpload(ImageSource.camera),
          ),
          if (hasAvatar) ...[
            const SizedBox(height: 10),
            _AvatarActionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Supprimer la photo',
              danger: true,
              onTap: _confirmAvatarRemoval,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startAvatarUpload(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      await widget.onAvatarSourceSelected(source);
    } catch (_) {
      // The provider exposes a sanitized retryable error state.
    }
  }

  Future<void> _confirmAvatarRemoval() async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Supprimer la photo ?',
          style: _text(size: 19, weight: FontWeight.w800),
        ),
        content: Text(
          'Vos initiales seront affichées à la place.',
          style: _text(size: 13.5, weight: FontWeight.w500, color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.onAvatarRemove();
    } catch (_) {
      // The provider exposes a sanitized error state.
    }
  }

  Future<void> _retryAvatar() async {
    try {
      await widget.onAvatarRetry?.call();
    } catch (_) {
      // The provider refreshes the same error state on another failure.
    }
  }

  Future<void> _showPersonalInformation() {
    return _showSheet(
      title: 'Informations personnelles',
      child: _PersonalInformationForm(
        identity: widget.identity,
        onSubmit: widget.onPersonalInformationChanged,
      ),
    );
  }

  Future<void> _showFamily() {
    return _showSheet(
      title: 'Ma famille',
      child: Column(
        children: [
          if (widget.familyIsLoading && widget.familyMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else if (widget.familyErrorMessage != null &&
              widget.familyMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, color: _muted, size: 30),
                  const SizedBox(height: 8),
                  Text(
                    widget.familyErrorMessage!,
                    textAlign: TextAlign.center,
                    style: _text(
                      size: 13,
                      weight: FontWeight.w500,
                      color: _muted,
                    ),
                  ),
                  if (widget.onRetryFamily != null) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: widget.onRetryFamily,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ],
              ),
            )
          else if (widget.familyMembers.isEmpty)
            const _EmptySheetState(
              icon: Icons.family_restroom_rounded,
              title: 'Aucun membre ajouté',
            )
          else
            for (final member in widget.familyMembers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF9),
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _ProfileAvatar(
                        name: member.name,
                        avatarUrl: member.avatarUrl,
                        size: 46,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _text(size: 14, weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              member.relationship,
                              style: _text(
                                size: 12,
                                weight: FontWeight.w600,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!member.graduated &&
                          (widget.onEditFamilyMember != null ||
                              widget.onDeactivateFamilyMember != null))
                        PopupMenuButton<String>(
                          tooltip: 'Actions du membre',
                          icon: const Icon(
                            Icons.more_horiz_rounded,
                            color: _muted,
                            size: 21,
                          ),
                          onSelected: (action) async {
                            Navigator.of(context).pop();
                            if (action == 'edit') {
                              await widget.onEditFamilyMember?.call(member.id);
                            } else if (action == 'deactivate') {
                              await widget.onDeactivateFamilyMember?.call(
                                member.id,
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            if (widget.onEditFamilyMember != null)
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Modifier'),
                                ),
                              ),
                            if (widget.onDeactivateFamilyMember != null)
                              const PopupMenuItem(
                                value: 'deactivate',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.person_remove_outlined,
                                    color: Color(0xFFB42318),
                                  ),
                                  title: Text(
                                    'Retirer',
                                    style: TextStyle(color: Color(0xFFB42318)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          if (widget.onAddFamilyMember != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onAddFamilyMember?.call();
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                label: const Text('Ajouter un membre'),
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: _text(size: 14, weight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showLanguagePicker() {
    return _showSheet(
      title: 'Langue de l’application',
      child: _LanguagePreferenceForm(
        initialLanguage: widget.preferredLanguage,
        onSubmit: widget.onLanguageChanged,
      ),
    );
  }

  Future<void> _showNotificationPreferences() {
    return _showSheet(
      title: 'Notifications',
      child: _NotificationPreferencesForm(
        medications: widget.notificationMedications,
        appointments: widget.notificationAppointments,
        passport: widget.notificationPassport,
        onSubmit: widget.onNotificationPreferencesChanged,
      ),
    );
  }

  Future<void> _showSupport() {
    return _showSheet(
      title: 'Aide et support',
      child: _SheetMenu(
        items: const [
          _SheetMenuItem(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Contacter OmniCare',
          ),
          _SheetMenuItem(
            icon: Icons.question_answer_outlined,
            title: 'Questions fréquentes',
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacy() {
    return _showSheet(
      title: 'Confidentialité et conditions',
      child: _SheetMenu(
        items: const [
          _SheetMenuItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Politique de confidentialité',
          ),
          _SheetMenuItem(
            icon: Icons.description_outlined,
            title: 'Conditions d’utilisation',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Se déconnecter ?',
          style: _text(size: 19, weight: FontWeight.w800),
        ),
        content: Text(
          'Votre session sera fermée sur cet appareil.',
          style: _text(size: 13.5, weight: FontWeight.w500, color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _danger),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onLogout();
  }

  Future<void> _confirmDeleteAccount() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: _danger, size: 30),
        title: Text(
          'Supprimer le compte ?',
          textAlign: TextAlign.center,
          style: _text(size: 19, weight: FontWeight.w800),
        ),
        content: Text(
          'Cette action supprime définitivement votre compte et vos accès.',
          textAlign: TextAlign.center,
          style: _text(size: 13.5, weight: FontWeight.w500, color: _muted),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(foregroundColor: _danger),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSheet({required String title, required Widget child}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5DD),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: _text(size: 20, weight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 21),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: _text(
          size: 11.5,
          weight: FontWeight.w800,
          color: _muted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173B37).withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(height: 1, indent: 68, color: _line),
          ],
        ],
      ),
    );
  }
}

class _ProfileErrorBanner extends StatelessWidget {
  const _ProfileErrorBanner({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4ED),
        border: Border.all(color: const Color(0xFFFED7AA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _text(size: 12, weight: FontWeight.w600, color: _ink),
            ),
          ),
          if (onRetry != null)
            IconButton(
              tooltip: 'Fermer',
              onPressed: onRetry,
              icon: const Icon(Icons.close_rounded, size: 19, color: _muted),
            ),
        ],
      ),
    );
  }
}

class _AvatarErrorBanner extends StatelessWidget {
  const _AvatarErrorBanner({
    required this.message,
    this.onRetry,
    this.onDismiss,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4ED),
        border: Border.all(color: const Color(0xFFFED7AA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: _danger,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _text(size: 12, weight: FontWeight.w600, color: _ink),
            ),
          ),
          if (onRetry != null)
            IconButton(
              tooltip: 'Réessayer',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 19, color: _teal),
            ),
          if (onDismiss != null)
            IconButton(
              tooltip: 'Fermer',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 19, color: _muted),
            ),
        ],
      ),
    );
  }
}

class _AvatarActionTile extends StatelessWidget {
  const _AvatarActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final foreground = danger ? _danger : _ink;
    return Material(
      color: const Color(0xFFF8FAF9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: danger ? const Color(0xFFFDA29B) : _line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: danger ? _danger : _teal, size: 21),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  style: _text(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: foreground, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingText,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _text(size: 14, weight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _text(
                            size: 11.5,
                            weight: FontWeight.w500,
                            color: _muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingText != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      trailingText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: _text(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: _teal,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF98A2B3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyTile extends StatelessWidget {
  const _FamilyTile({required this.members, required this.onTap});

  final List<PatientProfileFamilyMember> members;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final count = members.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4ED),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.family_restroom_rounded,
                    color: Color(0xFFC4320A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ma famille',
                        style: _text(size: 14, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        count == 0
                            ? 'Aucun membre'
                            : '$count ${count == 1 ? 'membre' : 'membres'}',
                        style: _text(
                          size: 11.5,
                          weight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (members.isNotEmpty) _AvatarStack(members: members),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF98A2B3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.members});

  final List<PatientProfileFamilyMember> members;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(3).toList();
    return SizedBox(
      width: 24 + ((visible.length - 1) * 18),
      height: 30,
      child: Stack(
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * 18,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _ProfileAvatar(
                  name: visible[index].name,
                  avatarUrl: visible[index].avatarUrl,
                  size: 28,
                  showBorder: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.avatarUrl,
    required this.size,
    this.showBorder = true,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFD1FAE5),
        border: showBorder
            ? Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2)
            : null,
      ),
      child: url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => _AvatarInitials(name: name, size: size),
              errorWidget: (_, _, _) => _AvatarInitials(name: name, size: size),
            )
          : _AvatarInitials(name: name, size: size),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _initials(name),
        style: _text(size: size * 0.3, weight: FontWeight.w800, color: _teal),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.label,
    required this.value,
    this.verified = false,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool verified;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: _line))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: _text(size: 12, weight: FontWeight.w600, color: _muted),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: _text(size: 13, weight: FontWeight.w700),
                  ),
                ),
                if (verified) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.verified_rounded, size: 15, color: _mint),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalInformationForm extends StatefulWidget {
  const _PersonalInformationForm({
    required this.identity,
    required this.onSubmit,
  });

  final PatientProfileIdentity identity;
  final PersonalInformationChanged onSubmit;

  @override
  State<_PersonalInformationForm> createState() =>
      _PersonalInformationFormState();
}

class _PersonalInformationFormState extends State<_PersonalInformationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _dateController;
  late DateTime? _dateOfBirth;
  late String? _gender;
  Map<String, String> _fieldErrors = const {};
  String? _errorMessage;
  bool _saving = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.identity.firstName,
    );
    _lastNameController = TextEditingController(text: widget.identity.lastName);
    _dateOfBirth = widget.identity.dateOfBirth;
    _dateController = TextEditingController(text: _formatDate(_dateOfBirth));
    _gender = _normalizedGender(widget.identity.gender);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: _ProfileAvatar(
                name:
                    '${_firstNameController.text} ${_lastNameController.text}',
                avatarUrl: widget.identity.avatarUrl,
                size: 76,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('profile-first-name'),
              controller: _firstNameController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 100,
              decoration: _fieldDecoration(
                label: 'Prénom',
                icon: Icons.person_outline_rounded,
              ),
              validator: (value) => _validateName(value, 'firstName'),
              onChanged: (_) {
                setState(() => _clearFieldError('firstName', notify: false));
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('profile-last-name'),
              controller: _lastNameController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 100,
              decoration: _fieldDecoration(
                label: 'Nom',
                icon: Icons.badge_outlined,
              ),
              validator: (value) => _validateName(value, 'lastName'),
              onChanged: (_) {
                setState(() => _clearFieldError('lastName', notify: false));
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('profile-date-of-birth'),
              controller: _dateController,
              enabled: !_saving,
              readOnly: true,
              decoration: _fieldDecoration(
                label: 'Date de naissance',
                icon: Icons.calendar_today_outlined,
                suffixIcon: const Icon(Icons.expand_more_rounded),
              ),
              validator: (_) =>
                  _fieldErrors['dateOfBirth'] ??
                  (_dateOfBirth == null
                      ? 'Sélectionnez votre date de naissance.'
                      : null),
              onTap: _saving ? null : _pickDateOfBirth,
            ),
            const SizedBox(height: 12),
            FormField<String>(
              key: const ValueKey('profile-gender'),
              initialValue: _gender,
              validator: (value) =>
                  _fieldErrors['gender'] ??
                  (value == null ? 'Sélectionnez votre genre.' : null),
              builder: (field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Genre',
                      style: _text(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'M', label: Text('Homme')),
                        ButtonSegment(value: 'F', label: Text('Femme')),
                        ButtonSegment(value: 'autre', label: Text('Autre')),
                      ],
                      selected: _gender == null ? const {} : {_gender!},
                      emptySelectionAllowed: true,
                      showSelectedIcon: false,
                      expandedInsets: EdgeInsets.zero,
                      onSelectionChanged: _saving
                          ? null
                          : (selection) {
                              final value = selection.isEmpty
                                  ? null
                                  : selection.first;
                              setState(() {
                                _gender = value;
                                _clearFieldError('gender', notify: false);
                              });
                              field.didChange(value);
                            },
                    ),
                    if (field.errorText != null) ...[
                      const SizedBox(height: 7),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          field.errorText!,
                          style: _text(
                            size: 12,
                            weight: FontWeight.w500,
                            color: _danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            const Divider(height: 1, color: _line),
            _InformationRow(
              label: 'Téléphone',
              value: _valueOrFallback(widget.identity.phoneNumber),
              verified: widget.identity.phoneVerified,
            ),
            _InformationRow(
              label: 'E-mail',
              value: _valueOrFallback(widget.identity.email),
              verified: widget.identity.emailVerified,
              showDivider: false,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _ProfileErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 20),
            _FormSaveButton(
              saving: _saving,
              retrying: _retrying,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  String? _validateName(String? value, String field) {
    final serverError = _fieldErrors[field];
    if (serverError != null) return serverError;
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Ce champ est obligatoire.';
    if (trimmed.length > 100) return 'Maximum 100 caractères.';
    return null;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final lastDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final firstDate = DateTime(1900);
    final current = _dateOfBirth;
    final initialDate =
        current != null &&
            !current.isBefore(firstDate) &&
            !current.isAfter(lastDate)
        ? current
        : DateTime(1990, 1, 1);
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _dateOfBirth = DateUtils.dateOnly(selected);
      _dateController.text = _formatDate(_dateOfBirth);
      _clearFieldError('dateOfBirth', notify: false);
    });
    _formKey.currentState?.validate();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _fieldErrors = const {};
      _errorMessage = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        gender: _gender!,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      final failure = _profileFormFailure(error, OmniLocalizations.of(context));
      setState(() {
        _fieldErrors = failure.fieldErrors;
        _errorMessage = failure.message;
        _retrying = true;
      });
      _formKey.currentState?.validate();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearFieldError(String field, {bool notify = true}) {
    if (!_fieldErrors.containsKey(field)) return;
    final updated = Map<String, String>.of(_fieldErrors)..remove(field);
    if (notify) {
      setState(() => _fieldErrors = updated);
    } else {
      _fieldErrors = updated;
    }
  }
}

class _LanguagePreferenceForm extends StatefulWidget {
  const _LanguagePreferenceForm({
    required this.initialLanguage,
    required this.onSubmit,
  });

  final String initialLanguage;
  final Future<void> Function(String language) onSubmit;

  @override
  State<_LanguagePreferenceForm> createState() =>
      _LanguagePreferenceFormState();
}

class _LanguagePreferenceFormState extends State<_LanguagePreferenceForm> {
  late String _selectedLanguage;
  bool _saving = false;
  bool _retrying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = _normalizeLanguage(widget.initialLanguage);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LanguageOption(
            title: 'Français',
            code: 'FR',
            selected: _selectedLanguage == 'fr',
            onTap: _saving ? null : () => _select('fr'),
          ),
          const SizedBox(height: 10),
          _LanguageOption(
            title: 'العربية',
            code: 'AR',
            selected: _selectedLanguage == 'ar',
            onTap: _saving ? null : () => _select('ar'),
          ),
          const SizedBox(height: 10),
          _LanguageOption(
            title: 'English',
            code: 'EN',
            selected: _selectedLanguage == 'en',
            onTap: _saving ? null : () => _select('en'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _ProfileErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 20),
          _FormSaveButton(
            saving: _saving,
            retrying: _retrying,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  void _select(String language) {
    setState(() {
      _selectedLanguage = language;
      _errorMessage = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_selectedLanguage == _normalizeLanguage(widget.initialLanguage)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(_selectedLanguage);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _profileFormFailure(
          error,
          OmniLocalizations.of(context),
        ).message;
        _retrying = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _NotificationPreferencesForm extends StatefulWidget {
  const _NotificationPreferencesForm({
    required this.medications,
    required this.appointments,
    required this.passport,
    required this.onSubmit,
  });

  final bool medications;
  final bool appointments;
  final bool passport;
  final NotificationPreferencesChanged onSubmit;

  @override
  State<_NotificationPreferencesForm> createState() =>
      _NotificationPreferencesFormState();
}

class _NotificationPreferencesFormState
    extends State<_NotificationPreferencesForm> {
  late bool _medications;
  late bool _appointments;
  late bool _passport;
  bool _saving = false;
  bool _retrying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _medications = widget.medications;
    _appointments = widget.appointments;
    _passport = widget.passport;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SwitchRow(
            icon: Icons.medication_outlined,
            title: 'Rappels de médicaments',
            value: _medications,
            onChanged: _saving
                ? null
                : (value) => setState(() => _medications = value),
          ),
          _SwitchRow(
            icon: Icons.calendar_month_outlined,
            title: 'Rendez-vous',
            value: _appointments,
            onChanged: _saving
                ? null
                : (value) => setState(() => _appointments = value),
          ),
          _SwitchRow(
            icon: Icons.shield_outlined,
            title: 'Activité du dossier médical',
            value: _passport,
            onChanged: _saving
                ? null
                : (value) => setState(() => _passport = value),
            showDivider: false,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _ProfileErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 20),
          _FormSaveButton(
            saving: _saving,
            retrying: _retrying,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final unchanged =
        _medications == widget.medications &&
        _appointments == widget.appointments &&
        _passport == widget.passport;
    if (unchanged) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(
        medications: _medications,
        appointments: _appointments,
        passport: _passport,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _profileFormFailure(
          error,
          OmniLocalizations.of(context),
        ).message;
        _retrying = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _FormSaveButton extends StatelessWidget {
  const _FormSaveButton({
    required this.saving,
    required this.retrying,
    required this.onPressed,
  });

  final bool saving;
  final bool retrying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton.icon(
        onPressed: saving ? null : onPressed,
        icon: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                retrying ? Icons.refresh_rounded : Icons.check_rounded,
                size: 19,
              ),
        label: Text(
          saving
              ? 'Enregistrement…'
              : retrying
              ? 'Réessayer'
              : 'Enregistrer',
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _teal.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: _text(size: 14, weight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ProfileFormFailure {
  const _ProfileFormFailure({required this.message, required this.fieldErrors});

  final String message;
  final Map<String, String> fieldErrors;
}

/// French message and per-field French texts for a failed profile save.
/// Never the server's text.
_ProfileFormFailure _profileFormFailure(Object error, OmniLocalizations l10n) {
  final failure = ApiFailure.from(error);
  return _ProfileFormFailure(
    message: apiFailureMessage(failure, l10n, fallback: l10n.profileSaveFailed),
    fieldErrors: apiFieldErrorMessages(failure.fieldErrors, l10n),
  );
}

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    suffixIcon: suffixIcon,
    counterText: '',
    filled: true,
    fillColor: const Color(0xFFF8FAF9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _teal, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _danger),
    ),
  );
}

String? _normalizedGender(String? gender) {
  final normalized = gender?.trim();
  return const {'M', 'F', 'autre'}.contains(normalized) ? normalized : null;
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.title,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String code;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _paleMint : const Color(0xFFF8FAF9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _mint : _line),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code,
                  style: _text(size: 11, weight: FontWeight.w800, color: _teal),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  style: _text(size: 14, weight: FontWeight.w700),
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? _mint : const Color(0xFFD0D5DD),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: _line))
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: _teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: _text(size: 13.5, weight: FontWeight.w700),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: _mint,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SheetMenu extends StatelessWidget {
  const _SheetMenu({required this.items});

  final List<_SheetMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            items[index],
            if (index < items.length - 1)
              const Divider(height: 1, indent: 52, color: _line),
          ],
        ],
      ),
    );
  }
}

class _SheetMenuItem extends StatelessWidget {
  const _SheetMenuItem({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _teal),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: _text(size: 13.5, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF98A2B3),
            size: 19,
          ),
        ],
      ),
    );
  }
}

class _EmptySheetState extends StatelessWidget {
  const _EmptySheetState({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: _paleMint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _teal, size: 25),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _text(size: 13.5, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

TextStyle _text({
  required double size,
  required FontWeight weight,
  Color color = _ink,
  double? height,
  double letterSpacing = 0,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

String _normalizeLanguage(String? language) {
  final normalized = language?.trim().toLowerCase();
  return switch (normalized) {
    'ar' => 'ar',
    'en' => 'en',
    _ => 'fr',
  };
}

String _languageName(String language) {
  return switch (language) {
    'ar' => 'العربية',
    'en' => 'English',
    _ => 'Français',
  };
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'OC' : initials;
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Non renseignée';
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _valueOrFallback(String value) {
  return value.trim().isEmpty ? 'Non renseigné' : value.trim();
}
