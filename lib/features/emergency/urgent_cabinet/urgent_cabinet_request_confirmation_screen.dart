import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../../../core/network/app_http_client.dart';
import '../../../core/theme/omni_theme.dart';
import '../../../providers/family_provider.dart';
import '../../../providers/user_provider.dart';
import 'urgent_cabinet_care_subject.dart';
import 'urgent_cabinet_doctor_detail.dart';
import 'urgent_cabinet_discovery_mapper.dart';
import 'urgent_cabinet_discovery_repository.dart';
import 'urgent_cabinet_doctor_source.dart';
import 'urgent_cabinet_flow_controller.dart';
import 'urgent_cabinet_flow_routes.dart';
import 'urgent_cabinet_patient_lifecycle_controller.dart';
import 'urgent_cabinet_request_review.dart';
import 'urgent_cabinet_request_source.dart';
import 'urgent_cabinet_submission_activation_gate.dart';
import 'urgent_cabinet_submission_coordinator.dart';
import 'urgent_cabinet_targeted_request_models.dart';

enum _ConfirmationLoadState { loading, loaded, error, unavailable }

class UrgentCabinetRequestConfirmationScreen extends StatefulWidget {
  const UrgentCabinetRequestConfirmationScreen({
    super.key,
    this.source,
    this.requestSource,
    this.activationGate = UrgentCabinetSubmissionActivationGate.p4Production,
  });

  final UrgentCabinetDoctorSource? source;
  final UrgentCabinetRequestSource? requestSource;

  /// Explicit test seam for fail-closed and synthetic scenarios.
  @visibleForTesting
  final UrgentCabinetSubmissionActivationGate activationGate;

  @override
  State<UrgentCabinetRequestConfirmationScreen> createState() =>
      _UrgentCabinetRequestConfirmationScreenState();
}

class _UrgentCabinetRequestConfirmationScreenState
    extends State<UrgentCabinetRequestConfirmationScreen> {
  UrgentCabinetDoctorSource? _source;
  UrgentCabinetDiscoveryRepository? _repository;
  CancelToken? _requestToken;
  _ConfirmationLoadState _loadState = _ConfirmationLoadState.loading;
  UrgentCabinetDoctorDetail? _doctor;
  UrgentCabinetLocationDetail? _cabinet;
  UrgentCabinetFeeQuote? _feeQuote;
  bool _requested = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _source = widget.source;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    if (_source == null) {
      _repository = AppUrgentCabinetDiscoveryRepository(
        context.read<AppHttpClient>(),
      );
    }
    _loadReviewData();
  }

  @override
  void dispose() {
    _requestToken?.cancel('urgent-cabinet-confirmation-disposed');
    super.dispose();
  }

  Future<void> _loadReviewData() async {
    final flow = context.read<UrgentCabinetFlowController>();
    final doctorId = flow.selectedDoctorId;
    final cabinetId = flow.selectedCabinetId;
    if (doctorId == null || cabinetId == null) {
      setState(() {
        _doctor = null;
        _cabinet = null;
        _feeQuote = null;
        _loadState = _ConfirmationLoadState.loaded;
      });
      return;
    }

    setState(() => _loadState = _ConfirmationLoadState.loading);
    try {
      final UrgentCabinetDoctorDetail? doctor;
      if (_source != null) {
        doctor = await _source!.loadDoctorDetail(doctorId);
      } else {
        _requestToken?.cancel('urgent-cabinet-confirmation-replaced');
        final token = CancelToken();
        _requestToken = token;
        final response = await _repository!.detail(
          doctorId: doctorId,
          practiceLocationId: cabinetId,
          cancelToken: token,
        );
        final pair = response.doctorCabinet;
        doctor = pair.toDetail(evaluatedAt: response.evaluatedAt);
      }
      final cabinet = doctor?.cabinetById(cabinetId);
      final snapshot = flow.quoteSnapshot;
      final feeQuote =
          doctor != null &&
              snapshot != null &&
              snapshot.doctorId == doctorId &&
              snapshot.cabinetId == cabinetId &&
              snapshot.matchesDetail(doctor)
          ? snapshot
          : null;
      if (snapshot != null && feeQuote == null) {
        flow.invalidateQuoteSnapshot();
      }
      if (!mounted) return;
      setState(() {
        _doctor = doctor;
        _cabinet = cabinet;
        _feeQuote = feeQuote;
        _loadState = _ConfirmationLoadState.loaded;
      });
    } on UrgentCabinetDoctorSourceUnavailable {
      if (!mounted) return;
      setState(() {
        _doctor = null;
        _cabinet = null;
        _feeQuote = null;
        _loadState = _ConfirmationLoadState.unavailable;
      });
    } on UrgentCabinetDiscoveryFailure catch (failure) {
      if (!mounted || failure.isCancelled) return;
      setState(() {
        _doctor = null;
        _cabinet = null;
        _feeQuote = null;
        _loadState = failure.isNotFound || failure.isFeatureUnavailable
            ? _ConfirmationLoadState.unavailable
            : _ConfirmationLoadState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadState = _ConfirmationLoadState.error);
    }
  }

  String? _patientDisplayName(
    UrgentCabinetCareSubject? subject,
    UserProvider userProvider,
    FamilyProvider familyProvider,
  ) {
    if (subject == null) return null;
    if (subject.isSelf) {
      final accountName = userProvider.user?.displayName.trim();
      if (accountName != null && accountName.isNotEmpty) return accountName;
      final profileName = userProvider.profile?.displayName.trim();
      if (profileName != null && profileName.isNotEmpty) return profileName;
      return null;
    }

    for (final member in familyProvider.members) {
      if (member.id == subject.familyMemberId) return member.fullName;
    }
    return null;
  }

  UrgentCabinetReviewValidation _validation({
    required UrgentCabinetFlowController flow,
    required UserProvider userProvider,
    required FamilyProvider familyProvider,
  }) {
    return validateUrgentCabinetRequestReview(
      careSubject: flow.selectedSubject,
      patientDisplayName: _patientDisplayName(
        flow.selectedSubject,
        userProvider,
        familyProvider,
      ),
      selectedDoctorId: flow.selectedDoctorId,
      selectedCabinetId: flow.selectedCabinetId,
      doctor: _doctor,
      cabinet: _cabinet,
      feeQuote: _feeQuote,
      developmentFixturesEnabled: _source?.isDevelopmentFixture == true,
      clinicalIntakeReady: flow.canReviewCurrentDraft,
    );
  }

  UrgentCabinetTargetedSubmissionValidation _submissionValidation(
    UrgentCabinetFlowController flow,
  ) {
    final intake = flow.clinicalIntakeDraft;
    final quote = flow.quoteSnapshot;
    if (intake == null || quote == null) {
      return const UrgentCabinetTargetedSubmissionValidation.invalid(
        UrgentCabinetSubmissionIssue.invalidClinicalIntake,
      );
    }
    return prepareUrgentCabinetTargetedSubmission(
      clinicalIntake: intake,
      quote: quote,
    );
  }

  bool _hasCurrentAuthoritativeTargetAndQuote({
    required UrgentCabinetReviewValidation reviewValidation,
    required UrgentCabinetTargetedSubmissionValidation submissionValidation,
  }) {
    final submission = submissionValidation.submission;
    final review = reviewValidation.review;
    return _source == null &&
        review != null &&
        submission != null &&
        !review.isDevelopmentFixture &&
        review.feeQuote.provenance == UrgentCabinetFeeProvenance.service &&
        review.doctorId == submission.doctorId &&
        review.cabinetId == submission.practiceLocationId &&
        review.feeQuote.amountMilliTnd == submission.amountMilliTnd &&
        review.feeQuote.configurationRevision ==
            submission.configurationRevision &&
        review.feeQuote.runtimeRevision == submission.runtimeRevision &&
        review.feeQuote.practiceLocationVersion ==
            submission.practiceLocationVersion;
  }

  Future<void> _submit() async {
    if (_submitting || _loadState != _ConfirmationLoadState.loaded) return;
    final flow = context.read<UrgentCabinetFlowController>();
    final user = context.read<UserProvider>();
    final family = context.read<FamilyProvider>();
    final lifecycle = context.read<UrgentCabinetPatientLifecycleController?>();
    final reviewValidation = _validation(
      flow: flow,
      userProvider: user,
      familyProvider: family,
    );
    final submissionValidation = _submissionValidation(flow);
    final accountId = user.profile?.userId;
    final subject = flow.selectedSubject;
    final hasCurrentAuthority = _hasCurrentAuthoritativeTargetAndQuote(
      reviewValidation: reviewValidation,
      submissionValidation: submissionValidation,
    );
    final previewSource = widget.requestSource;
    final previewReview = reviewValidation.review;
    if (lifecycle == null &&
        previewSource?.isDevelopmentFixture == true &&
        previewReview?.isDevelopmentFixture == true) {
      setState(() => _submitting = true);
      final transition = await flow.submitReview(
        review: previewReview!,
        source: previewSource!,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      if (transition == UrgentCabinetSubmitTransition.pending) {
        await Navigator.of(context).pushReplacementNamed<void, void>(
          UrgentCabinetFlowRoutes.requestWaiting,
        );
      }
      return;
    }
    if (lifecycle == null ||
        subject == null ||
        !widget.activationGate.allows(
          authenticatedAccountId: accountId,
          submission: submissionValidation,
          currentAuthoritativeTargetAndQuote: hasCurrentAuthority,
        )) {
      return;
    }

    setState(() => _submitting = true);
    final result = await lifecycle.submitAuthorized(
      activationGate: widget.activationGate,
      authenticatedAccountId: accountId,
      subject: subject,
      submissionValidation: submissionValidation,
      currentAuthoritativeTargetAndQuote: hasCurrentAuthority,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    final snapshot = result.snapshot;
    if (snapshot != null &&
        lifecycle.snapshot?.requestId == snapshot.requestId) {
      final patientName = reviewValidation.review?.patientDisplayName;
      if (patientName == null ||
          !flow.applyAuthoritativeSnapshot(
            snapshot: snapshot,
            patientDisplayName: patientName,
          )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La demande a été reçue, mais son affichage doit être récupéré.',
            ),
          ),
        );
        return;
      }
      final destination = switch (snapshot.responseStatus) {
        UrgentCabinetPatientResponseStatus.pending =>
          UrgentCabinetFlowRoutes.requestWaiting,
        UrgentCabinetPatientResponseStatus.accepted =>
          UrgentCabinetFlowRoutes.requestAccepted,
        UrgentCabinetPatientResponseStatus.declined ||
        UrgentCabinetPatientResponseStatus.cancelled ||
        UrgentCabinetPatientResponseStatus.expired ||
        // Unreachable: the repository rejects unrecognized snapshots.
        UrgentCabinetPatientResponseStatus.unknown =>
          UrgentCabinetFlowRoutes.requestRecovery,
      };
      await Navigator.of(context).pushReplacementNamed<void, void>(destination);
      return;
    }
    if (result.kind == UrgentCabinetSubmissionResultKind.unknownOutcome) {
      await Navigator.of(context).pushReplacementNamed<void, void>(
        UrgentCabinetFlowRoutes.requestRecovery,
      );
      return;
    }
    final message = result.failure?.message;
    if (message != null && message.trim().isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<UrgentCabinetFlowController>();
    final userProvider = context.watch<UserProvider>();
    final familyProvider = context.watch<FamilyProvider>();
    final validation = _loadState == _ConfirmationLoadState.loaded
        ? _validation(
            flow: flow,
            userProvider: userProvider,
            familyProvider: familyProvider,
          )
        : null;
    final submissionValidation = _submissionValidation(flow);
    final accountId = userProvider.profile?.userId;
    final hasCurrentAuthority =
        validation != null &&
        _hasCurrentAuthoritativeTargetAndQuote(
          reviewValidation: validation,
          submissionValidation: submissionValidation,
        );
    final previewCanSubmit =
        context.read<UrgentCabinetPatientLifecycleController?>() == null &&
        widget.requestSource?.isDevelopmentFixture == true &&
        validation?.review?.isDevelopmentFixture == true;
    final canSubmit =
        !_submitting &&
        validation?.isValid == true &&
        (previewCanSubmit ||
            widget.activationGate.allows(
              authenticatedAccountId: accountId,
              submission: submissionValidation,
              currentAuthoritativeTargetAndQuote: hasCurrentAuthority,
            ));

    return PopScope<void>(
      canPop: !_submitting && !flow.isSubmitting,
      child: Scaffold(
        key: const ValueKey('urgent-cabinet-request-confirmation-screen'),
        backgroundColor: OmniColors.pageBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _ConfirmationHeader(enabled: !_submitting && !flow.isSubmitting),
              Expanded(
                child: switch (_loadState) {
                  _ConfirmationLoadState.loading => const Center(
                    child: CircularProgressIndicator(
                      key: ValueKey('urgent-cabinet-confirmation-loading'),
                    ),
                  ),
                  _ConfirmationLoadState.error => _ConfirmationMessageState(
                    key: const ValueKey('urgent-cabinet-confirmation-error'),
                    icon: Icons.cloud_off_outlined,
                    title: 'Impossible de vérifier cette demande.',
                    message: 'Veuillez réessayer dans un instant.',
                    actionLabel: 'Réessayer',
                    onAction: _loadReviewData,
                  ),
                  _ConfirmationLoadState.unavailable =>
                    const _ConfirmationMessageState(
                      key: ValueKey('urgent-cabinet-confirmation-unavailable'),
                      icon: Icons.info_outline_rounded,
                      title: 'Tarif urgent indisponible',
                      message:
                          'Le tarif urgent au cabinet n’est pas encore disponible '
                          'depuis un service approuvé.',
                    ),
                  _ConfirmationLoadState.loaded => _ConfirmationContent(
                    patientName: _patientDisplayName(
                      flow.selectedSubject,
                      userProvider,
                      familyProvider,
                    ),
                    doctor: _doctor,
                    cabinet: _cabinet,
                    feeQuote: _feeQuote,
                    issue: validation?.issue,
                  ),
                },
              ),
              _ConfirmationFooter(
                enabled: canSubmit,
                submitting: _submitting || flow.isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationHeader extends StatelessWidget {
  const _ConfirmationHeader({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.sm,
        OmniSpacing.sm,
        OmniSpacing.pageHorizontal,
        OmniSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border(bottom: BorderSide(color: OmniColors.borderLight)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: enabled ? () => Navigator.of(context).maybePop() : null,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: OmniColors.textPrimary,
            ),
          ),
          const SizedBox(width: OmniSpacing.xs),
          Expanded(
            child: Text(
              'Vérifier la demande',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: OmniColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationContent extends StatelessWidget {
  const _ConfirmationContent({
    required this.patientName,
    required this.doctor,
    required this.cabinet,
    required this.feeQuote,
    required this.issue,
  });

  final String? patientName;
  final UrgentCabinetDoctorDetail? doctor;
  final UrgentCabinetLocationDetail? cabinet;
  final UrgentCabinetFeeQuote? feeQuote;
  final UrgentCabinetReviewIssue? issue;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const PageStorageKey('urgent-cabinet-confirmation-scroll'),
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.lg,
        OmniSpacing.pageHorizontal,
        OmniSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Votre demande urgente au cabinet',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: OmniColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              Text(
                "Vérifiez les informations avant d'envoyer votre demande.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: OmniColors.textSecondary,
                ),
              ),
              const SizedBox(height: OmniSpacing.xl),
              _SummaryCard(
                icon: Icons.person_outline_rounded,
                iconColor: OmniColors.violet,
                iconBackground: OmniColors.violetSoft,
                title: 'Patient concerné',
                primary: _availableOrFallback(patientName),
              ),
              const SizedBox(height: OmniSpacing.md),
              _SummaryCard(
                icon: Icons.medical_services_outlined,
                iconColor: OmniColors.clinicalCyan,
                iconBackground: OmniColors.clinicalCyanSoft,
                title: 'Médecin',
                primary: _availableOrFallback(doctor?.displayName),
                secondary: doctor?.specialty,
              ),
              const SizedBox(height: OmniSpacing.md),
              _SummaryCard(
                icon: Icons.location_on_outlined,
                iconColor: OmniColors.infoBlue,
                iconBackground: OmniColors.infoBlueSoft,
                title: 'Cabinet',
                primary: _availableOrFallback(cabinet?.name),
                secondary: _cabinetAddress(cabinet),
              ),
              const SizedBox(height: OmniSpacing.md),
              _SummaryCard(
                key: const ValueKey('urgent-cabinet-confirmation-fee'),
                icon: Icons.payments_outlined,
                iconColor: OmniColors.deepTeal,
                iconBackground: OmniColors.mintSoft,
                title: 'Tarif de consultation urgente',
                primary: feeQuote == null
                    ? 'Indisponible'
                    : formatUrgentCabinetFee(feeQuote!),
                badge: feeQuote?.isDevelopmentFixture == true
                    ? 'Tarif de démonstration'
                    : null,
              ),
              if (issue != null) ...[
                const SizedBox(height: OmniSpacing.md),
                _ValidationMessage(issue: issue!),
              ],
              const SizedBox(height: OmniSpacing.lg),
              const _DoctorConfirmationNotice(),
            ],
          ),
        ),
      ),
    );
  }

  static String _availableOrFallback(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Information indisponible'
        : normalized;
  }

  static String? _cabinetAddress(UrgentCabinetLocationDetail? cabinet) {
    if (cabinet == null) return null;
    final parts = <String>[];
    final address = cabinet.address?.trim();
    if (address != null && address.isNotEmpty) parts.add(address);
    final locality = cabinet.locality.trim();
    if (locality.isNotEmpty) parts.add(locality);
    final region = cabinet.city == cabinet.governorate
        ? cabinet.city
        : '${cabinet.city}, ${cabinet.governorate}';
    if (region.trim().isNotEmpty && !parts.contains(region)) parts.add(region);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.primary,
    this.secondary,
    this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String primary;
  final String? secondary;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(OmniRadii.field),
            ),
            child: Icon(icon, size: 21, color: iconColor),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: OmniSpacing.xs),
                Text(
                  primary,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: OmniColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (secondary?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: OmniSpacing.xs),
                  Text(
                    secondary!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ],
                if (badge != null) ...[
                  const SizedBox(height: OmniSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OmniSpacing.sm,
                      vertical: OmniSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: OmniColors.amberSoft,
                      borderRadius: BorderRadius.circular(OmniRadii.pill),
                    ),
                    child: Text(
                      badge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: OmniColors.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage({required this.issue});

  final UrgentCabinetReviewIssue issue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('urgent-cabinet-confirmation-invalid'),
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: OmniColors.errorSoft,
          borderRadius: BorderRadius.circular(OmniRadii.field),
          border: Border.all(color: OmniColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: OmniColors.error, size: 20),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Text(
                _issueMessage(issue),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: OmniColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _issueMessage(UrgentCabinetReviewIssue issue) {
    return switch (issue) {
      UrgentCabinetReviewIssue.missingCareSubject =>
        'Sélectionnez de nouveau la personne qui a besoin de soins.',
      UrgentCabinetReviewIssue.missingPatient =>
        'La personne sélectionnée n’est plus disponible. Revenez en arrière pour la sélectionner de nouveau.',
      UrgentCabinetReviewIssue.missingDoctor =>
        'Le médecin sélectionné est introuvable.',
      UrgentCabinetReviewIssue.doctorMismatch =>
        'Les informations du médecin ne correspondent plus à votre sélection.',
      UrgentCabinetReviewIssue.missingCabinet =>
        'Le cabinet sélectionné est introuvable.',
      UrgentCabinetReviewIssue.cabinetMismatch =>
        'Ce cabinet n’est pas associé au médecin sélectionné.',
      UrgentCabinetReviewIssue.doctorIneligible =>
        'Ce médecin n’est plus éligible aux demandes urgentes au cabinet.',
      UrgentCabinetReviewIssue.doctorUnavailable =>
        'Ce médecin n’est plus disponible pour une demande urgente.',
      UrgentCabinetReviewIssue.missingFee =>
        'Le tarif urgent au cabinet est indisponible pour cette sélection.',
      UrgentCabinetReviewIssue.feeDoctorMismatch ||
      UrgentCabinetReviewIssue.feeCabinetMismatch =>
        'Le tarif ne correspond pas au médecin et au cabinet sélectionnés.',
      UrgentCabinetReviewIssue.invalidFee =>
        'Le tarif urgent reçu est invalide.',
      UrgentCabinetReviewIssue.incompleteFeeAuthority =>
        'Le tarif urgent doit être vérifié de nouveau avant de continuer.',
      UrgentCabinetReviewIssue.expiredFee =>
        'Ce tarif urgent a expiré. Revenez aux détails pour actualiser la demande.',
      UrgentCabinetReviewIssue.missingClinicalIntake =>
        'Complétez les symptômes avant de vérifier la demande.',
      UrgentCabinetReviewIssue.provenanceMismatch ||
      UrgentCabinetReviewIssue.developmentFixtureUnavailable =>
        'Les données de démonstration ne sont pas disponibles dans cet environnement.',
    };
  }
}

class _DoctorConfirmationNotice extends StatelessWidget {
  const _DoctorConfirmationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-confirmation-safety-notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.infoBlueSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.infoBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: OmniColors.infoBlue,
            size: 22,
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendez la confirmation du médecin',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: OmniColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: OmniSpacing.xs),
                Text(
                  "Le médecin doit accepter votre demande avant votre déplacement. N'allez pas au cabinet tant que vous n'avez pas reçu sa confirmation dans OmniCare.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.5,
                    color: OmniColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationFooter extends StatelessWidget {
  const _ConfirmationFooter({
    required this.enabled,
    required this.submitting,
    required this.onPressed,
  });

  final bool enabled;
  final bool submitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.pageHorizontal,
          OmniSpacing.sm,
          OmniSpacing.pageHorizontal,
          OmniSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: OmniColors.surfacePrimary,
          border: Border(top: BorderSide(color: OmniColors.borderLight)),
        ),
        child: ElevatedButton(
          key: const ValueKey('urgent-cabinet-confirmation-submit'),
          style: buildOmniPrimaryButtonStyle(),
          onPressed: enabled ? onPressed : null,
          child: submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: OmniColors.textTertiary,
                  ),
                )
              : const Text('Envoyer la demande'),
        ),
      ),
    );
  }
}

class _ConfirmationMessageState extends StatelessWidget {
  const _ConfirmationMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(OmniSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: OmniColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: OmniColors.slateBlue, size: 28),
            ),
            const SizedBox(height: OmniSpacing.base),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: OmniColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: OmniColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: OmniSpacing.lg),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
