import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../emergency/emergency_request_step0.dart';
import '../../emergency/emergency_request_step1.dart';
import '../../emergency/emergency_request_step2.dart';
import '../../emergency/emergency_request_step3.dart';
import '../../emergency/emergency_review_screen.dart';
import '../../emergency/p4_synthetic_emergency_location_adapter.dart';
import '../data/synthetic_cabinet_directory_source.dart';
import '../data/synthetic_home_location_gateway.dart';
import '../data/synthetic_urgent_journey_fixture_source.dart';
import '../domain/p4_urgent_feature_gate.dart';
import '../domain/urgent_journey_intents.dart';
import '../domain/urgent_journey_models.dart';
import 'p4_attempt_setup_screens.dart';
import 'p4_urgent_copy.dart';

enum P4UrgentCoordinatorStage {
  mode,
  subject,
  triage,
  homeDestination,
  cabinetDirectory,
  review,
  setupComplete,
}

/// Single API-free owner of Patient P4 entry and static attempt setup.
class P4UrgentJourneyCoordinator extends StatefulWidget {
  const P4UrgentJourneyCoordinator({
    super.key,
    this.initialStage = P4UrgentCoordinatorStage.mode,
    this.initialMode,
    this.fixtureSource,
    this.locationGateway,
    this.directorySource,
    this.featureGate = P4UrgentFeatureGate.runtime,
  }) : assert(
         initialStage == P4UrgentCoordinatorStage.mode || initialMode != null,
         'A direct entry after mode selection requires an immutable mode.',
       );

  final P4UrgentCoordinatorStage initialStage;
  final UrgentAttemptMode? initialMode;
  final SyntheticUrgentJourneyFixtureSource? fixtureSource;
  final SyntheticHomeLocationGateway? locationGateway;
  final SyntheticCabinetDirectorySource? directorySource;
  final P4UrgentFeatureGate featureGate;

  @override
  State<P4UrgentJourneyCoordinator> createState() => _CoordinatorState();
}

class _CoordinatorState extends State<P4UrgentJourneyCoordinator> {
  late final SyntheticUrgentJourneyFixtureSource _source =
      widget.fixtureSource ?? SyntheticUrgentJourneyFixtureSource();
  late final SyntheticHomeLocationGateway _location =
      widget.locationGateway ?? InMemorySyntheticHomeLocationGateway();
  late final P4SyntheticEmergencyLocationAdapter _locationAdapter =
      P4SyntheticEmergencyLocationAdapter(_location);
  late final P4SyntheticEmergencyPlacesAdapter _placesAdapter =
      P4SyntheticEmergencyPlacesAdapter(_location);
  late final SyntheticCabinetDirectorySource _directory =
      widget.directorySource ?? SyntheticCabinetDirectorySource();
  late P4UrgentCoordinatorStage _stage = widget.initialStage;
  late UrgentAttemptMode? _mode = widget.initialMode;
  SubjectSelectionUiRef? _subjectRef;
  PatientUrgentJourneyProjection? _journey;
  CabinetTargetProjection? _pendingTarget;
  UrgentSafeError? _error;
  int _action = 0;
  String _arrivalInstructions = '';

  @override
  void initState() {
    super.initState();
    if (!widget.featureGate.isEnabled) return;
    final existing = _source.snapshot().patientJourney;
    if (existing != null) {
      _journey = existing;
      _mode = existing.activeAttempt.mode;
      _subjectRef = existing.subject.selectionRef;
      _pendingTarget = existing.activeAttempt is CabinetAttemptProjection
          ? (existing.activeAttempt as CabinetAttemptProjection).target
          : null;
      _stage = _stageFor(existing.activeAttempt);
    }
  }

  P4UrgentCoordinatorStage _stageFor(UrgentAttemptProjection attempt) {
    if (!attempt.triage.isValid) return P4UrgentCoordinatorStage.triage;
    return switch (attempt.stage) {
      UrgentAttemptStage.triageSetup => P4UrgentCoordinatorStage.triage,
      UrgentAttemptStage.homeDestinationSetup =>
        P4UrgentCoordinatorStage.homeDestination,
      UrgentAttemptStage.cabinetTargetSelection =>
        P4UrgentCoordinatorStage.cabinetDirectory,
      UrgentAttemptStage.setupReview => P4UrgentCoordinatorStage.review,
      UrgentAttemptStage.awaitingCabinetDoctor =>
        P4UrgentCoordinatorStage.setupComplete,
      _ => P4UrgentCoordinatorStage.setupComplete,
    };
  }

  void _setMode(UrgentAttemptMode mode) => setState(() {
    _mode = mode;
    _subjectRef = null;
    _error = null;
    _stage = P4UrgentCoordinatorStage.subject;
  });

  List<PatientOption> get _patientOptions => _source
      .snapshot()
      .subjectChoices
      .map(
        (choice) => PatientOption(
          id: choice.selectionRef.value,
          name: choice.displayLabel,
          type: choice.kind == CareSubjectKind.self ? 'me' : 'family',
          relationship: choice.relationshipLabel,
        ),
      )
      .toList(growable: false);

  void _selectSubject(PatientOption? option) => setState(() {
    _subjectRef = option == null ? null : SubjectSelectionUiRef(option.id);
    _error = null;
  });

  void _confirmSubject(PatientOption option) {
    final selection = SubjectSelectionUiRef(option.id);
    _subjectRef = selection;
    final journey = _journey;
    if (journey != null) {
      if (journey.subject.selectionRef == selection) {
        setState(() {
          _error = null;
          _stage = P4UrgentCoordinatorStage.triage;
        });
      } else {
        setState(() {
          _error = const UrgentSafeError(
            code: UrgentSafeErrorCode.transitionNotAllowed,
            messageKey: 'urgent.error.subject_locked',
            retryable: false,
          );
        });
      }
      return;
    }
    _start(selection);
  }

  void _back() {
    if (_stage == P4UrgentCoordinatorStage.mode) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _error = null;
      _stage = switch (_stage) {
        P4UrgentCoordinatorStage.subject => P4UrgentCoordinatorStage.mode,
        P4UrgentCoordinatorStage.triage => P4UrgentCoordinatorStage.subject,
        P4UrgentCoordinatorStage.homeDestination ||
        P4UrgentCoordinatorStage.cabinetDirectory =>
          P4UrgentCoordinatorStage.triage,
        P4UrgentCoordinatorStage.review =>
          _mode == UrgentAttemptMode.home
              ? P4UrgentCoordinatorStage.homeDestination
              : P4UrgentCoordinatorStage.cabinetDirectory,
        P4UrgentCoordinatorStage.setupComplete =>
          P4UrgentCoordinatorStage.review,
        P4UrgentCoordinatorStage.mode => P4UrgentCoordinatorStage.mode,
      };
    });
  }

  void _start(SubjectSelectionUiRef selection) {
    if (_mode == null) return;
    _apply(
      _source.execute(
        StartUrgentJourneyIntent(
          actionId: 'ui-start-${_action++}',
          accountScopeRef: SyntheticUrgentJourneyFixtureSource.patientAccount,
          subjectSelectionRef: selection,
          initialMode: _mode!,
        ),
      ),
      P4UrgentCoordinatorStage.triage,
    );
  }

  void _saveLegacyTriage(Map<String, dynamic> data) {
    final pain = ((data['painLevel'] as num?)?.round() ?? 5).clamp(1, 10);
    final areas = (data['bodyParts'] as List? ?? const <Object>[])
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final note = (data['description'] ?? '').toString().trim();
    final band = pain <= 3
        ? 'MILD'
        : pain <= 6
        ? 'MODERATE'
        : 'SEVERE';
    _saveTriage(
      PatientTriageProjection(
        minimum: StructuredTriageMinimumProjection(
          bodyAreaCodes: areas,
          painIntensity: pain,
          painBandCode: 'SYNTHETIC_${band}_PENDING_APPROVAL',
          painBandDisplayKey: 'p4_pain_${band.toLowerCase()}',
        ),
        privateNarrative: note.isEmpty
            ? null
            : PatientPrivateNarrativeProjection(value: note),
      ),
    );
  }

  void _confirmLegacyDestination(
    SelectedConsultationLocation location,
    String arrivalInstructions,
  ) {
    _arrivalInstructions = arrivalInstructions;
    _confirmDestination(_locationAdapter.confirm(location));
  }

  void _saveTriage(PatientTriageProjection triage) {
    final attempt = _journey!.activeAttempt;
    _apply(
      _source.execute(
        SaveStructuredTriageIntent(
          actionId: 'ui-triage-${_action++}',
          accountScopeRef: _journey!.requestingAccountScopeRef,
          journeyRef: _journey!.journeyRef,
          attemptRef: attempt.attemptRef,
          triage: triage,
          expectedJourneyVersion: _journey!.version,
          expectedAttemptVersion: attempt.version,
        ),
      ),
      _mode == UrgentAttemptMode.home
          ? P4UrgentCoordinatorStage.homeDestination
          : P4UrgentCoordinatorStage.cabinetDirectory,
    );
  }

  void _confirmDestination(HomeDestinationDraft destination) {
    final attempt = _journey!.activeAttempt;
    _apply(
      _source.execute(
        ConfirmHomeDestinationIntent(
          actionId: 'ui-destination-${_action++}',
          accountScopeRef: _journey!.requestingAccountScopeRef,
          journeyRef: _journey!.journeyRef,
          attemptRef: attempt.attemptRef,
          destination: destination,
          expectedJourneyVersion: _journey!.version,
          expectedAttemptVersion: attempt.version,
        ),
      ),
      P4UrgentCoordinatorStage.review,
    );
  }

  void _selectTarget(CabinetTargetProjection target) => setState(() {
    _pendingTarget = target;
    _stage = P4UrgentCoordinatorStage.review;
  });

  void _finishSetup() {
    if (_mode == UrgentAttemptMode.home) {
      setState(() => _stage = P4UrgentCoordinatorStage.setupComplete);
      return;
    }
    final attempt = _journey!.activeAttempt;
    _apply(
      _source.execute(
        ChooseCabinetTargetIntent(
          actionId: 'ui-target-${_action++}',
          accountScopeRef: _journey!.requestingAccountScopeRef,
          journeyRef: _journey!.journeyRef,
          attemptRef: attempt.attemptRef,
          target: _pendingTarget!,
          expectedJourneyVersion: _journey!.version,
          expectedAttemptVersion: attempt.version,
        ),
      ),
      P4UrgentCoordinatorStage.setupComplete,
    );
  }

  void _apply(UrgentUiCommandResult result, P4UrgentCoordinatorStage next) =>
      setState(() {
        switch (result) {
          case UrgentUiCommandSuccess(:final projection):
            _journey = projection;
            _error = null;
            _stage = next;
          case UrgentUiCommandFailure(:final error, :final latestProjection):
            _error = error;
            _journey = latestProjection ?? _journey;
        }
      });

  Map<String, dynamic> _presentationData() {
    final journey = _journey;
    final subject = journey?.subject;
    final attempt = journey?.activeAttempt;
    final triage = attempt?.triage;
    final destination = attempt is HomeAttemptProjection
        ? attempt.destination ??
              (_stage == P4UrgentCoordinatorStage.homeDestination
                  ? _location.snapshot()
                  : null)
        : null;
    return <String, dynamic>{
      'patientId': subject?.selectionRef.value,
      'patientName': subject?.displayLabel ?? 'Patient démo',
      'patientType': subject?.kind == CareSubjectKind.self ? 'me' : 'family',
      if (subject?.kind == CareSubjectKind.familyMember)
        'relationship': subject?.relationshipLabel,
      'providerType': 'doctor',
      'consultationType': _mode == UrgentAttemptMode.home ? 'home' : 'cabinet',
      'bodyParts': triage?.minimum.bodyAreaCodes ?? const <String>[],
      'painLevel': (triage?.minimum.painIntensity ?? 0) >= 1
          ? triage!.minimum.painIntensity
          : 5,
      'description': triage?.privateNarrative?.value ?? '',
      'symptoms': triage?.privateNarrative?.value ?? '',
      'voiceMessage': null,
      'shareMedicalRecord': false,
      if (destination?.displayAddress != null)
        'address': destination!.displayAddress,
      if (destination?.displayAddress != null)
        'location': <String, dynamic>{
          'type': destination!.source == HomeDestinationSource.manualAddress
              ? 'manual'
              : 'gps',
          'source': destination.source == HomeDestinationSource.manualAddress
              ? ConsultationLocationSource.manual.name
              : ConsultationLocationSource.currentLocation.name,
          'latitude': destination.latitude,
          'longitude': destination.longitude,
          'address': destination.displayAddress,
          'fullAddress': destination.displayAddress,
          'arrivalInstructions': _arrivalInstructions,
        },
    };
  }

  EmergencyCabinetReviewTarget? get _cabinetReviewTarget {
    final target = _pendingTarget;
    if (target == null) return null;
    return EmergencyCabinetReviewTarget(
      doctorName: target.doctorDisplayName,
      specialtyLabel: target.specialtyLabel,
      cabinetName: target.cabinetDisplayName,
      publicAddress: target.publicAddress,
      feeLabel: target.quote.displayAmount,
      feeVersion: target.quote.feeVersion.toString(),
    );
  }

  void _editStage(P4UrgentCoordinatorStage stage) => setState(() {
    _error = null;
    _stage = stage;
  });

  @override
  Widget build(BuildContext context) {
    if (!widget.featureGate.isEnabled) {
      return const P4UrgentFeatureUnavailableScreen();
    }
    final content = switch (_stage) {
      P4UrgentCoordinatorStage.mode => EmergencyRequestStep0(
        onClose: () => Navigator.of(context).maybePop(),
        onHomeSelected: () => _setMode(UrgentAttemptMode.home),
        onCabinetSelected: () => _setMode(UrgentAttemptMode.cabinet),
      ),
      P4UrgentCoordinatorStage.subject => EmergencyRequestStep1(
        key: const ValueKey('p4-recovered-subject-screen'),
        patientOptions: _patientOptions,
        initialSelectedPatientId: _subjectRef?.value,
        onClose: _back,
        onSelectionChanged: _selectSubject,
        onContinue: _confirmSubject,
        errorText: _error?.messageKey,
      ),
      P4UrgentCoordinatorStage.triage =>
        _source.triageAvailability == SyntheticTriageAvailability.ready
            ? EmergencyRequestStep2(
                key: const ValueKey('p4-recovered-triage-screen'),
                step1Data: _presentationData(),
                p4SafePresentation: true,
                onBack: _back,
                onContinue: _saveLegacyTriage,
              )
            : P4StructuredTriageScreen(
                availability: _source.triageAvailability,
                initialValue: _journey?.activeAttempt.triage,
                onBack: _back,
                onContinue: _saveTriage,
                onRetry: () => setState(_source.retryTriage),
              ),
      P4UrgentCoordinatorStage.homeDestination => EmergencyRequestStep3(
        key: const ValueKey('p4-recovered-destination-screen'),
        previousData: _presentationData(),
        locationGateway: _locationAdapter,
        placesGateway: _placesAdapter,
        mapsEnabled: false,
        onBack: _back,
        onContinue: _confirmLegacyDestination,
      ),
      P4UrgentCoordinatorStage.cabinetDirectory => P4CabinetDirectoryScreen(
        source: _directory,
        initialTarget: _pendingTarget,
        onBack: _back,
        onConfirmed: _selectTarget,
      ),
      P4UrgentCoordinatorStage.review => EmergencyReviewScreen(
        key: const ValueKey('p4-recovered-review-screen'),
        requestData: _presentationData(),
        locationGateway: _locationAdapter,
        placesGateway: _placesAdapter,
        mapsEnabled: false,
        onBack: _back,
        onEditPatient: () => _editStage(P4UrgentCoordinatorStage.subject),
        onEditSymptoms: () => _editStage(P4UrgentCoordinatorStage.triage),
        onEditModeSpecific: () => _editStage(
          _mode == UrgentAttemptMode.home
              ? P4UrgentCoordinatorStage.homeDestination
              : P4UrgentCoordinatorStage.cabinetDirectory,
        ),
        onSubmit: _finishSetup,
        cabinetTarget: _cabinetReviewTarget,
        afterSendText: p4Copy(context, 'p4_setup_stop'),
        submitLabel: p4Copy(context, 'p4_confirm_setup'),
      ),
      P4UrgentCoordinatorStage.setupComplete => _CompleteScreen(
        mode: _mode!,
        onBack: _back,
      ),
    };
    return PopScope<void>(
      canPop: _stage == P4UrgentCoordinatorStage.mode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ColoredBox(color: OmniColors.pageBackground, child: content),
    );
  }
}

class _CompleteScreen extends StatelessWidget {
  const _CompleteScreen({required this.mode, required this.onBack});
  final UrgentAttemptMode mode;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      key: const ValueKey('p4-setup-complete'),
      children: [
        _Header(title: p4Copy(context, 'p4_setup_complete'), onBack: onBack),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(OmniSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: OmniColors.deepTeal,
                    size: 52,
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  _ModePill(mode: mode),
                  const SizedBox(height: OmniSpacing.md),
                  Text(
                    p4Copy(context, 'p4_setup_stop'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Retour',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode});
  final UrgentAttemptMode mode;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      key: ValueKey('p4-mode-${mode.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: mode == UrgentAttemptMode.home
            ? OmniColors.mintSoft
            : OmniColors.infoBlueSoft,
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      child: Text(
        mode.name.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class P4UrgentFeatureUnavailableScreen extends StatelessWidget {
  const P4UrgentFeatureUnavailableScreen({super.key});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: OmniColors.pageBackground,
    child: SafeArea(
      child: Center(
        child: Padding(
          key: const ValueKey('p4-synthetic-unavailable'),
          padding: const EdgeInsets.all(OmniSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 48,
                color: OmniColors.deepTeal,
              ),
              const SizedBox(height: OmniSpacing.md),
              Text(
                p4Copy(context, 'p4_feature_unavailable'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OmniSpacing.sm),
              Text(
                p4Copy(context, 'p4_feature_unavailable_body'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
