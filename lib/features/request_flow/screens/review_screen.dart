import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../providers/family_provider.dart';
import '../../patient_clinic/application/patient_clinic_directory_controller.dart';
import '../../patient_clinic/presentation/widgets/clinic_image_renderer.dart';
import '../../request_core/application/request_submission_controller.dart';
import '../../request_core/domain/pickup_location.dart';
import '../../request_core/domain/request_vocabulary.dart';
import 'pickup_screen.dart';
import 'situation_screen.dart';
import 'who_needs_care_screen.dart';

/// Step 5 — Review your request.
///
/// One cohesive confirmation surface adapted from Airbnb's confirmation
/// principles: clinic identity at top, review rows with human-friendly labels,
/// quiet Change actions, and a clear post-send explanation.
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

    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        backgroundColor: OmniColors.pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 56,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 24,
            color: OmniColors.textPrimary,
          ),
        ),
        titleSpacing: 0,
        title: Text(
          'Review your request',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: OmniColors.textPrimary,
            letterSpacing: -0.45,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.sm,
                OmniSpacing.pageHorizontal,
                OmniSpacing.xxl,
              ),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
                    border: Border.all(color: OmniColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ClinicSummary(clinic: clinic),
                      _Divider(),
                      _ReviewRow(
                        label: 'Patient',
                        value: _patientLabel(request),
                        semanticsLabel: 'Change patient',
                        icon: request.subject.isSelf
                            ? Icons.person_outline_rounded
                            : Icons.family_restroom_rounded,
                        iconColor: OmniColors.slateBlue,
                        onChanged: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WhoNeedsCareScreen(),
                          ),
                        ),
                      ),
                      _Divider(),
                      _ReviewRow(
                        label: 'Care type',
                        value: _situationLabel(situation),
                        semanticsLabel: 'Change care type',
                        icon: _situationIcon(situation),
                        iconColor: _situationIconColor(situation),
                        onChanged: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SituationScreen(),
                          ),
                        ),
                      ),
                      if (situation == RequestSituation.ambulance) ...[
                        _Divider(),
                        _ReviewRow(
                          label: 'Pickup location',
                          value: _pickupLabel(request.selectedPickup),
                          semanticsLabel: 'Change pickup location',
                          icon: Icons.location_on_outlined,
                          iconColor: OmniColors.infoBlue,
                          onChanged: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PickupScreen(),
                            ),
                          ),
                        ),
                      ],
                      _Divider(),
                      _PostSendInfo(),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          _SendRequestFooter(
            enabled: request.canSubmit && !request.isSubmitting,
            isSubmitting: request.isSubmitting,
            onPressed: () => _send(context),
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
      RequestSituation.appointment => 'Planned care',
      RequestSituation.urgent => 'Urgent care',
      RequestSituation.ambulance => 'Medical transport',
      _ => 'Not selected',
    };
  }

  IconData _situationIcon(RequestSituation? situation) {
    return switch (situation) {
      RequestSituation.appointment => Icons.info_outline_rounded,
      RequestSituation.urgent => Icons.priority_high_outlined,
      RequestSituation.ambulance => Icons.emergency_outlined,
      _ => Icons.help_outline_rounded,
    };
  }

  Color _situationIconColor(RequestSituation? situation) {
    return switch (situation) {
      RequestSituation.appointment => OmniColors.infoBlue,
      RequestSituation.urgent => OmniColors.urgentCoral,
      RequestSituation.ambulance => OmniColors.clinicalCyan,
      _ => OmniColors.textTertiary,
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

// ---------------------------------------------------------------------------
// Clinic summary — top of the review container
// ---------------------------------------------------------------------------

class _ClinicSummary extends StatelessWidget {
  const _ClinicSummary({required this.clinic});

  final dynamic clinic;

  @override
  Widget build(BuildContext context) {
    final imageUrl = clinic?.primaryImageUrl;
    final name = clinic?.displayName ?? 'Selected clinic';
    final city = clinic?.city;
    final governorate = clinic?.governorate;
    final accepting = clinic?.acceptingRequests;

    final location = <String>[
      if (city != null) city,
      if (governorate != null) governorate,
    ].join(', ');

    return Padding(
      padding: const EdgeInsets.all(OmniSpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ClinicImageRenderer.networkUrl(
                    imageUrl,
                    width: 78,
                    height: 78,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: OmniColors.slateSoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.medical_services_outlined,
                      size: 28,
                      color: OmniColors.slateBlue,
                    ),
                  ),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: OmniColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      location,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: OmniColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (accepting != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 15,
                          color: accepting
                              ? OmniColors.freshMint
                              : OmniColors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          accepting ? 'Accepting requests' : 'Not accepting',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: accepting
                                ? OmniColors.deepTeal
                                : OmniColors.amber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Review row — repeated pattern for each section
// ---------------------------------------------------------------------------

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    required this.semanticsLabel,
    required this.icon,
    required this.iconColor,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String semanticsLabel;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.base,
        vertical: 18,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OmniColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: OmniColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: semanticsLabel,
            child: GestureDetector(
              onTap: onChanged,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: OmniColors.slateSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Change',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OmniColors.slateBlue,
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

// ---------------------------------------------------------------------------
// Divider
// ---------------------------------------------------------------------------

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: OmniSpacing.base),
      child: Divider(
        height: 1,
        thickness: 1,
        color: OmniColors.borderLight,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post-send information
// ---------------------------------------------------------------------------

class _PostSendInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.base,
        18,
        OmniSpacing.base,
        OmniSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happens after you send?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OmniColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "The clinic reviews your request and you\u2019ll receive the next steps in OmniCare.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              height: 1.5,
              color: OmniColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky footer — Send request CTA
// ---------------------------------------------------------------------------

class _SendRequestFooter extends StatelessWidget {
  const _SendRequestFooter({
    required this.enabled,
    required this.isSubmitting,
    required this.onPressed,
  });

  final bool enabled;
  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: OmniColors.borderLight),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: enabled ? onPressed : null,
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send request'),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error banner
// ---------------------------------------------------------------------------

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
      margin: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.sm,
        OmniSpacing.pageHorizontal,
        0,
      ),
      decoration: BoxDecoration(
        color: OmniColors.errorSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: OmniColors.error,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
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
