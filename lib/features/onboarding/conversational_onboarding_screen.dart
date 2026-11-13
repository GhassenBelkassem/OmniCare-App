import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/account_api.dart';
import '../../core/models/blood_type.dart';
import '../../core/theme/omni_theme.dart';
import '../../core/utils/logger.dart';
import '../../core/widgets/omni_birth_date_picker.dart';
import '../../core/widgets/omni_choice_tile.dart';
import '../../core/widgets/omni_number_wheel.dart';
import '../../core/widgets/omni_option_row.dart';
import '../../core/widgets/omni_pressable.dart';
import '../../core/widgets/omni_segmented_choice.dart';
import '../../core/widgets/omni_text_field.dart';
import '../../core/widgets/omni_weight_ruler.dart';
import '../../providers/user_onboarding_provider.dart';
import '../../providers/user_provider.dart';
import 'onboarding_basics_payload.dart';
import '../../core/l10n/blood_type_label.dart';
import '../../core/network/api_failure.dart';
import '../../l10n/omni_localizations.dart';
import 'onboarding_labels.dart';
import '../patient_passport/data/medical_record_repository.dart';
import '../patient_passport/data/medical_record_write_repository.dart';
import 'onboarding_progress.dart';
import 'onboarding_complete_screen.dart';
import 'onboarding_validation.dart';
import 'widgets/bmi_card.dart';
import 'widgets/onboarding_frame.dart';
import 'widgets/onboarding_intro.dart';
import 'widgets/onboarding_note.dart';
import 'widgets/profile_summary_card.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Patient medical onboarding (G3-ONB2 restyle, same logic and data).
///
/// Same 5-page [PageView] (order and [OnboardingPage] indexes unchanged,
/// swipe as before, resume with `jumpToPage`), each page in an
/// [OnboardingFrame]. Page 1 shows three local sub-steps (blood type,
/// height, weight) and saves on the last one, as its single « Continue »
/// did. The progress bar counts 7 visual steps. The intro is shown above
/// the PageView on a fresh start only; the PageView stays mounted below it
/// (and below the initial-load spinner) so resume can jump.
class ConversationalOnboardingScreen extends StatefulWidget {
  const ConversationalOnboardingScreen({
    super.key,
    required this.accountApi,
    required this.medicalRecords,
    required this.medicalRecordWrites,
  });

  final AccountApi accountApi;

  /// The record's read and section saves (the body page, G2.1-A3).
  final MedicalRecordRepository medicalRecords;
  final MedicalRecordWriteRepository medicalRecordWrites;

  @override
  State<ConversationalOnboardingScreen> createState() =>
      _ConversationalOnboardingScreenState();
}

class _ConversationalOnboardingScreenState
    extends State<ConversationalOnboardingScreen> {
  final PageController _pageController = PageController();
  AccountApi get _accountApi => widget.accountApi;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  int _currentPage = 0;
  bool _saving = false;
  bool _profilePrefillStarted = false;

  /// Saves page by page and knows the server progress (G2-1a-6).
  late final OnboardingProgressController _progress =
      OnboardingProgressController(
        _accountApi,
        records: widget.medicalRecords,
        writes: widget.medicalRecordWrites,
      );
  DateTime? _selectedDateOfBirth;
  String? _selectedGender;

  final List<BloodType> bloodTypes = const [
    BloodType.aPositive,
    BloodType.aNegative,
    BloodType.bPositive,
    BloodType.bNegative,
    BloodType.abPositive,
    BloodType.abNegative,
    BloodType.oPositive,
    BloodType.oNegative,
    BloodType.unknown,
  ];

  final List<String> availableConditions = [
    'Diabetes',
    'Hypertension',
    'Asthma',
    'Heart Disease',
    'Arthritis',
    'Thyroid Disorder',
    'Kidney Disease',
    'Liver Disease',
    'Cancer',
    'Epilepsy',
    'COPD',
    'Depression',
    'Anxiety',
    'Migraine',
  ];

  List<String> _filteredConditions = [];
  final TextEditingController _searchController = TextEditingController();
  final List<TextEditingController> _allergyNameControllers = [];
  final List<String> _allergySeverities = [];
  final List<bool> _allergyLifeSafety = [];

  // ── G3-ONB2 UI state only (nothing here is sent) ─────────────────────────

  /// False until the resume read finished (full-screen spinner).
  bool _resumeReady = false;

  /// Intro above the PageView: fresh start only (resume landed on page 0).
  bool _showIntro = false;

  /// Page 0: the fields replace the summary card (« Modifier », a missing
  /// value, or a failed check).
  bool _editingProfile = false;

  /// Page 1 sub-step: 0 blood type, 1 height, 2 weight.
  int _bodyStep = 0;

  /// Page 1: the type-in weight field is open.
  bool _weightTypeIn = false;

  /// Oui / Non answers of pages 2–4 (null = not answered on screen).
  bool? _hasAllergies;
  bool? _hasConditions;
  bool? _takesMedications;

  /// Message of the last failed check, shown inline on the current page.
  String? _validationMessage;

  static const int _visualSteps = 7;
  static const int _heightMin = 30;
  static const int _heightMax = 299;
  static const int _heightRest = 170;
  static const int _weightMin = 1;
  static const int _weightMax = 499;
  static const int _weightRest = 70;

  @override
  void initState() {
    super.initState();
    _filteredConditions = availableConditions;
    _addAllergyFields();
    _heightController.addListener(_refreshBodyMeasurementPreview);
    _weightController.addListener(_refreshBodyMeasurementPreview);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profilePrefillStarted) return;
    _profilePrefillStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startResume();
    });
  }

  /// Runs the unchanged [_loadResume], then decides whether the intro shows:
  /// only when resume left the PageView on the first page.
  Future<void> _startResume() async {
    await _loadResume();
    if (!mounted) return;
    final page = _pageController.hasClients
        ? (_pageController.page ?? 0).round()
        : _currentPage;
    setState(() {
      _resumeReady = true;
      _showIntro = page == OnboardingPage.identity;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _searchController.dispose();
    for (var controller in _allergyNameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addAllergyFields() {
    _allergyNameControllers.add(TextEditingController());
    _allergySeverities.add('modérée');
    _allergyLifeSafety.add(false);
  }

  void _removeAllergyFields(int index) {
    if (_allergyNameControllers.length > 1) {
      _allergyNameControllers[index].dispose();
      setState(() {
        _allergyNameControllers.removeAt(index);
        _allergySeverities.removeAt(index);
        _allergyLifeSafety.removeAt(index);
      });
    }
  }

  /// Filters the 14 conditions by their French label (accents ignored).
  /// The list keeps the stored English values.
  void _filterConditions(String query) {
    final l10n = OmniLocalizations.of(context);
    setState(() {
      if (query.isEmpty) {
        _filteredConditions = availableConditions;
      } else {
        final key = onboardingSearchKey(query.trim());
        _filteredConditions = availableConditions
            .where(
              (condition) => onboardingSearchKey(
                onboardingConditionLabel(condition, l10n),
              ).contains(key),
            )
            .toList();
      }
    });
  }

  int get _pageCount => 5;
  int get _lastPageIndex => _pageCount - 1;

  int? get _heightCm => int.tryParse(_heightController.text.trim());
  double? get _weightKg =>
      double.tryParse(_weightController.text.trim().replaceAll(',', '.'));

  double? get _bmiPreview {
    final height = _heightCm;
    final weight = _weightKg;
    if (height == null || height <= 0 || weight == null || weight <= 0) {
      return null;
    }
    final meters = height / 100;
    return weight / (meters * meters);
  }

  void _refreshBodyMeasurementPreview() {
    if (mounted) setState(() {});
  }

  /// Pre-fills what the server already has and opens the first page that
  /// is not saved yet. A failed read keeps the screen as it opens today.
  Future<void> _loadResume() async {
    final resume = await _progress.load();
    if (!mounted) return;
    final profile = resume.profile;
    final basics = resume.storedBasics;
    setState(() {
      if (profile != null) {
        if (_firstNameController.text.trim().isEmpty) {
          _firstNameController.text = profile.firstName;
        }
        if (_lastNameController.text.trim().isEmpty) {
          _lastNameController.text = profile.lastName;
        }
        if (_selectedDateOfBirth == null && profile.dateOfBirth != null) {
          _selectedDateOfBirth = profile.dateOfBirth;
          _dateOfBirthController.text = _formatDobDisplay(profile.dateOfBirth!);
        }
        if ((_selectedGender ?? '').trim().isEmpty &&
            (profile.gender ?? '').trim().isNotEmpty) {
          _selectedGender = profile.gender;
        }
      }
      if (basics != null && basics.hasBodyMeasurements) {
        if (_heightController.text.trim().isEmpty) {
          _heightController.text = '${basics.heightCm}';
        }
        if (_weightController.text.trim().isEmpty) {
          _weightController.text = _formatWeight(basics.weightKg!);
        }
      }
    });
    final preselect = bloodTypeToPreselect(_progress.storedBloodType);
    final provider = context.read<UserOnboardingProvider>();
    if (preselect != null && provider.bloodGroup == null) {
      provider.setBloodGroup(preselect.wireValue);
    }
    if (_selectedDateOfBirth != null && _selectedGender != null) {
      _progress.rememberShownValues(_readDraft());
    }
    if (resume.page != OnboardingPage.identity && _currentPage == 0) {
      _pageController.jumpToPage(resume.page);
    }
  }

  static String _formatWeight(double weightKg) =>
      weightKg == weightKg.roundToDouble()
      ? weightKg.toInt().toString()
      : weightKg.toString();

  /// « Continue » / last page: saves every unsaved page up to this one,
  /// then moves on. On failure the page and what was typed stay.
  Future<void> _nextPage() async {
    if (_saving) return;
    final page = _currentPage;
    if (!_validateThrough(page)) return;
    final draft = _buildDraft();

    setState(() => _saving = true);
    final outcome = await _progress.saveThrough(page, draft);
    if (!mounted) return;
    setState(() => _saving = false);

    switch (outcome) {
      case OnboardingSaveIgnored():
        return;
      case OnboardingSaveFailed(:final error):
        AppLogger.error(
          'Failed to save onboarding page $page',
          ApiFailure.from(error).logSummary,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              onboardingSaveErrorMessage(error, OmniLocalizations.of(context)),
            ),
          ),
        );
        return;
      case OnboardingSaved(:final alreadySavedPageEdited):
        if (alreadySavedPageEdited) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                OmniLocalizations.of(context).onboardingPageAlreadySaved,
              ),
            ),
          );
        }
        if (page < _lastPageIndex) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
          return;
        }
        await _finishOnboarding();
    }
  }

  /// Validates every page up to [page] (pages can be swiped past).
  bool _validateThrough(int page) {
    if (!_validateBasicProfile(showError: true)) return false;
    if (page >= OnboardingPage.body &&
        !_validateBodyMeasurements(showError: true)) {
      return false;
    }
    if (page >= OnboardingPage.allergies &&
        !_validateAllergies(showError: true)) {
      return false;
    }
    if (page >= OnboardingPage.conditions &&
        !_validateConditions(showError: true)) {
      return false;
    }
    return true;
  }

  /// Reads the screen into a draft (and the onboarding provider, as before).
  OnboardingDraft _buildDraft() {
    final provider = Provider.of<UserOnboardingProvider>(
      context,
      listen: false,
    );
    provider.setBasicProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      dateOfBirth: _selectedDateOfBirth!,
      gender: _selectedGender!,
    );
    provider.setBodyMeasurements(heightCm: _heightCm, weightKg: _weightKg);
    provider.setAllergies(_collectAllergies());
    return _readDraft();
  }

  /// What the screen shows, without side effects. Needs a birth date and a
  /// gender (validated or pre-filled before any call). Conditions are sent
  /// with the French label the patient chose (G2.1-A3), never the internal
  /// key.
  OnboardingDraft _readDraft() {
    final provider = context.read<UserOnboardingProvider>();
    final l10n = OmniLocalizations.of(context);
    return OnboardingDraft(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      dateOfBirth: _formatDateOnly(_selectedDateOfBirth!),
      gender: _selectedGender!,
      chosenBloodType: BloodType.fromWire(provider.bloodGroup),
      heightCm: _heightCm,
      weightKg: _weightKg,
      allergies: _collectAllergies(),
      conditions: _conditionLabels(provider, l10n),
      takesMedications: _takesMedications,
    );
  }

  List<String> _conditionLabels(
    UserOnboardingProvider provider,
    OmniLocalizations l10n,
  ) => [
    for (final condition in provider.chronicConditions)
      onboardingConditionLabel(condition, l10n),
  ];

  Future<void> _finishOnboarding() async {
    final userProvider = context.read<UserProvider>();
    try {
      await userProvider.refresh();
    } catch (e, st) {
      AppLogger.error('Failed to refresh profile after onboarding', e, st);
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingCompleteScreen()),
    );
  }

  // Same three checks and order as before; the texts are French (ARB) and
  // the message is shown inline instead of a SnackBar (G3-ONB2).

  bool _validateBasicProfile({required bool showError}) {
    final l10n = OmniLocalizations.of(context);
    String? message;
    if (_firstNameController.text.trim().isEmpty) {
      message = l10n.onboardingErrorFirstName;
    } else if (_lastNameController.text.trim().isEmpty) {
      message = l10n.onboardingErrorLastName;
    } else if (_selectedDateOfBirth == null) {
      message = l10n.onboardingErrorBirthDate;
    } else if (!_selectedDateOfBirth!.isBefore(DateTime.now())) {
      message = l10n.onboardingErrorBirthDatePast;
    } else if ((_selectedGender ?? '').trim().isEmpty) {
      message = l10n.onboardingErrorGender;
    }

    if (message == null) return true;
    if (showError) _showInlineError(message, profile: true);
    return false;
  }

  bool _validateBodyMeasurements({required bool showError}) {
    final message = onboardingMeasurementsError(
      rawHeight: _heightController.text,
      rawWeight: _weightController.text,
      heightCm: _heightCm,
      weightKg: _weightKg,
      l10n: OmniLocalizations.of(context),
    );
    if (message == null) return true;
    if (showError) _showInlineError(message);
    return false;
  }

  bool _validateAllergies({required bool showError}) {
    final hasInput = _allergyNameControllers.any(
      (controller) => controller.text.trim().isNotEmpty,
    );
    final message = onboardingAllergiesError(
      answer: _hasAllergies ?? (hasInput ? true : null),
      rows: [
        for (var i = 0; i < _allergyNameControllers.length; i++)
          (
            name: _allergyNameControllers[i].text,
            severity: _allergySeverities[i],
            lifeSafety: _allergyLifeSafety[i],
          ),
      ],
      l10n: OmniLocalizations.of(context),
    );
    if (message == null) return true;
    if (showError) _showInlineError(message);
    return false;
  }

  bool _validateConditions({required bool showError}) {
    final provider = context.read<UserOnboardingProvider>();
    final l10n = OmniLocalizations.of(context);
    final message = onboardingConditionsError(
      answer:
          _hasConditions ??
          (provider.chronicConditions.isNotEmpty ? true : null),
      conditions: _conditionLabels(provider, l10n),
      l10n: l10n,
    );
    if (message == null) return true;
    if (showError) _showInlineError(message);
    return false;
  }

  /// Inline sink of the three checks: the message shows on the current
  /// page; a profile failure also opens the profile fields.
  void _showInlineError(String message, {bool profile = false}) {
    setState(() {
      _validationMessage = message;
      if (profile) _editingProfile = true;
    });
  }

  List<AllergyEntry> _collectAllergies() {
    final entries = <AllergyEntry>[];
    for (var i = 0; i < _allergyNameControllers.length; i++) {
      final name = _allergyNameControllers[i].text.trim();
      if (name.isEmpty) continue;
      entries.add(
        AllergyEntry(
          name: name,
          severity: _allergySeverities[i],
          lifeSafety: _allergyLifeSafety[i],
        ),
      );
    }
    return entries;
  }

  void _clearAllergies() {
    setState(() {
      for (var i = _allergyNameControllers.length - 1; i > 0; i--) {
        _allergyNameControllers[i].dispose();
        _allergyNameControllers.removeAt(i);
        _allergySeverities.removeAt(i);
        _allergyLifeSafety.removeAt(i);
      }
      if (_allergyNameControllers.isEmpty) {
        _allergyNameControllers.add(TextEditingController());
        _allergySeverities.add('modérée');
        _allergyLifeSafety.add(false);
      }
      _allergyNameControllers.first.clear();
      _allergySeverities.first = 'modérée';
      _allergyLifeSafety.first = false;
    });
  }

  /// The former AppBar « Skip » (same navigation).
  void _skip() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  /// The former AppBar back arrow (same animation).
  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showOmniBirthDatePicker(
      context,
      initialDate: _selectedDateOfBirth ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return;
    setState(() {
      _selectedDateOfBirth = picked;
      _dateOfBirthController.text = _formatDobDisplay(picked);
      _validationMessage = null;
    });
  }

  static String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _formatDobDisplay(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year.toString().padLeft(4, '0')}';
  }

  // ── G3-ONB2 UI ─────────────────────────────────────────────────────────

  /// Main button of a page that saves: clears the inline message, then the
  /// unchanged [_nextPage].
  void _submitPage() {
    if (_validationMessage != null) {
      setState(() => _validationMessage = null);
    }
    _nextPage();
  }

  void _clearValidation() {
    if (_validationMessage != null) {
      setState(() => _validationMessage = null);
    }
  }

  double _progressFor(int step) => step / _visualSteps;

  bool get _profileComplete =>
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _selectedDateOfBirth != null &&
      (_selectedGender ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserOnboardingProvider>(context);
    final l10n = OmniLocalizations.of(context);
    final covered = !_resumeReady || _showIntro;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        children: [
          // Always mounted so the resume jump works under the covers.
          Offstage(
            offstage: covered,
            child: TickerMode(
              enabled: !covered,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                    _validationMessage = null;
                  });
                },
                children: [
                  _buildBasicProfilePage(l10n),
                  _buildBloodTypePage(provider, l10n),
                  _buildAllergiesPage(l10n),
                  _buildConditionsPage(provider, l10n),
                  _buildMedicationsPage(l10n),
                ],
              ),
            ),
          ),
          if (_resumeReady && _showIntro)
            Positioned.fill(
              child: OnboardingIntro(
                onStart: () => setState(() => _showIntro = false),
                onLater: _skip,
              ),
            ),
          if (!_resumeReady)
            Positioned.fill(
              child: ColoredBox(
                color: OmniColors.surfacePrimary,
                child: Center(
                  child: CircularProgressIndicator(
                    color: OmniColors.deepTeal,
                    semanticsLabel: l10n.onboardingLoading,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Inline message of the last failed check (alert role), or nothing.
  Widget _inlineError() {
    final message = _validationMessage;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: OmniSpacing.md),
      child: Semantics(
        role: SemanticsRole.alert,
        container: true,
        child: Container(
          padding: const EdgeInsets.all(OmniSpacing.md),
          decoration: BoxDecoration(
            color: OmniColors.errorSoft,
            borderRadius: BorderRadius.circular(OmniRadii.field),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 20,
                  color: OmniColors.error,
                ),
              ),
              const SizedBox(width: OmniSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: _bundledFont,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: OmniColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Page 0 « Profil » (visual step 1) ───────────────────────────────────

  Widget _buildBasicProfilePage(OmniLocalizations l10n) {
    final showForm = _editingProfile || !_profileComplete;
    return OnboardingFrame(
      progress: _progressFor(1),
      title: l10n.onboardingProfileTitle,
      subtitle: l10n.onboardingProfileSubtitle,
      onSkip: _skip,
      primaryLabel: showForm
          ? l10n.onboardingContinue
          : l10n.onboardingProfileConfirm,
      onPrimary: _submitPage,
      primaryLoading: _saving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showForm)
            ..._profileFields(l10n)
          else
            ProfileSummaryCard(
              fullName:
                  '${_firstNameController.text.trim()} '
                  '${_lastNameController.text.trim()}',
              rows: [
                ProfileSummaryRow(
                  label: l10n.onboardingBirthDate,
                  value: _dateOfBirthController.text,
                ),
                ProfileSummaryRow(
                  label: l10n.onboardingGender,
                  value: onboardingGenderLabel(_selectedGender, l10n),
                ),
              ],
              onEdit: () => setState(() => _editingProfile = true),
            ),
          _inlineError(),
        ],
      ),
    );
  }

  List<Widget> _profileFields(OmniLocalizations l10n) {
    return [
      OmniTextField(
        label: l10n.onboardingFirstName,
        controller: _firstNameController,
        maxLength: 100,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        prefixIcon: Icons.person_outline_rounded,
        onChanged: (_) => _clearValidation(),
      ),
      const SizedBox(height: OmniSpacing.base),
      OmniTextField(
        label: l10n.onboardingLastName,
        controller: _lastNameController,
        maxLength: 100,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        prefixIcon: Icons.person_outline_rounded,
        onChanged: (_) => _clearValidation(),
      ),
      const SizedBox(height: OmniSpacing.base),
      OmniTextField(
        label: l10n.onboardingBirthDate,
        controller: _dateOfBirthController,
        readOnly: true,
        onTap: _pickDateOfBirth,
        prefixIcon: Icons.calendar_today_rounded,
        suffix: const ExcludeSemantics(
          child: Icon(
            Icons.expand_more_rounded,
            color: OmniColors.textSecondary,
          ),
        ),
      ),
      const SizedBox(height: OmniSpacing.base),
      Text(
        l10n.onboardingGender,
        style: const TextStyle(
          fontFamily: _bundledFont,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: OmniColors.textPrimary,
        ),
      ),
      const SizedBox(height: OmniSpacing.sm),
      OmniSegmentedChoice<String>(
        semanticLabel: l10n.onboardingGender,
        value: _selectedGender,
        options: [
          OmniChoiceOption(value: 'M', label: l10n.onboardingGenderMale),
          OmniChoiceOption(value: 'F', label: l10n.onboardingGenderFemale),
          OmniChoiceOption(value: 'autre', label: l10n.onboardingGenderOther),
        ],
        onChanged: (value) => setState(() {
          _selectedGender = value;
          _validationMessage = null;
        }),
      ),
    ];
  }

  // ── Page 1: « Groupe sanguin », « Taille », « Poids » (steps 2–4) ──────

  Widget _buildBloodTypePage(
    UserOnboardingProvider provider,
    OmniLocalizations l10n,
  ) {
    final step = _bodyStep;
    final String title;
    final String? subtitle;
    final Widget content;
    final bool enabled;
    switch (step) {
      case 0:
        title = l10n.onboardingBloodTitle;
        subtitle = l10n.onboardingBloodSubtitle;
        content = _bloodTypeGrid(provider, l10n);
        enabled = true;
      case 1:
        title = l10n.onboardingHeightTitle;
        subtitle = null;
        content = _heightStep(l10n);
        enabled = _heightController.text.trim().isNotEmpty;
      default:
        title = l10n.onboardingWeightTitle;
        subtitle = null;
        content = _weightStep(l10n);
        enabled = _weightController.text.trim().isNotEmpty;
    }
    return OnboardingFrame(
      progress: _progressFor(2 + step),
      previousProgress: _progressFor(1 + step),
      title: title,
      subtitle: subtitle,
      onBack: step > 0
          ? () => setState(() => _bodyStep = step - 1)
          : _previousPage,
      onSkip: _skip,
      primaryLabel: l10n.onboardingContinue,
      primaryEnabled: enabled,
      primaryLoading: _saving,
      onPrimary: step < 2
          ? () => setState(() {
              _bodyStep = step + 1;
              _validationMessage = null;
            })
          : _submitPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [content, _inlineError()],
      ),
    );
  }

  Widget _bloodTypeGrid(
    UserOnboardingProvider provider,
    OmniLocalizations l10n,
  ) {
    final groups = bloodTypes.where((type) => type.isKnown).toList();
    final unknown = bloodTypes.firstWhere((type) => !type.isKnown);
    Widget tile(BloodType bloodType) => OmniChoiceTile(
      label: bloodType.label(l10n),
      selected: provider.bloodGroup == bloodType.wireValue,
      onTap: () {
        provider.setBloodGroup(bloodType.wireValue);
      },
    );
    return Semantics(
      role: SemanticsRole.radioGroup,
      label: l10n.onboardingSummaryBlood,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var row = 0; row < groups.length; row += 3) ...[
            if (row > 0) const SizedBox(height: OmniSpacing.md),
            Row(
              children: [
                for (var i = row; i < row + 3; i++) ...[
                  if (i > row) const SizedBox(width: OmniSpacing.md),
                  Expanded(
                    child: i < groups.length
                        ? tile(groups[i])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: OmniSpacing.md),
          OmniChoiceTile.wide(
            label: unknown.label(l10n),
            selected: provider.bloodGroup == unknown.wireValue,
            onTap: () {
              provider.setBloodGroup(unknown.wireValue);
            },
          ),
        ],
      ),
    );
  }

  Widget _heightStep(OmniLocalizations l10n) {
    return OmniNumberWheel(
      min: _heightMin,
      max: _heightMax,
      value: _heightCm,
      unit: l10n.onboardingUnitCm,
      initialPosition: _heightRest,
      semanticLabel: l10n.onboardingHeightLabel,
      onChanged: (value) {
        _validationMessage = null;
        _heightController.text = '$value';
      },
    );
  }

  Widget _weightStep(OmniLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OmniWeightRuler(
          min: _weightMin,
          max: _weightMax,
          value: _weightKg,
          unit: l10n.onboardingUnitKg,
          initialPosition: _weightRest,
          semanticLabel: l10n.onboardingWeightLabel,
          onChanged: (value) {
            _validationMessage = null;
            _weightController.text = '$value';
          },
        ),
        const SizedBox(height: OmniSpacing.md),
        if (_weightTypeIn)
          OmniTextField(
            label: l10n.onboardingWeightFieldLabel,
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onChanged: (_) => _clearValidation(),
          )
        else
          Center(
            child: OmniPressable(
              borderRadius: OmniRadii.field,
              builder: (context, states) => TextButton.icon(
                statesController: states,
                onPressed: () => setState(() => _weightTypeIn = true),
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
                  foregroundColor: const WidgetStatePropertyAll(
                    OmniColors.deepTeal,
                  ),
                  overlayColor: OmniPressable.overlay(OmniColors.deepTeal),
                ),
                icon: const Icon(Icons.keyboard_outlined, size: 20),
                label: Text(
                  l10n.onboardingWeightTypeIn,
                  style: const TextStyle(
                    fontFamily: _bundledFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: OmniSpacing.base),
        // The existing BMI preview (same formula), shown by the card.
        BmiCard(bmi: _bmiPreview, heightCm: _heightCm),
      ],
    );
  }

  // ── Page 2 « Allergies » (step 5) ───────────────────────────────────────

  Widget _buildAllergiesPage(OmniLocalizations l10n) {
    final hasInput = _allergyNameControllers.any(
      (controller) => controller.text.trim().isNotEmpty,
    );
    final answer = _hasAllergies ?? (hasInput ? true : null);
    return OnboardingFrame(
      progress: _progressFor(5),
      previousProgress: _progressFor(4),
      title: l10n.onboardingAllergiesTitle,
      subtitle: l10n.onboardingAllergiesSubtitle,
      onBack: _previousPage,
      onSkip: _skip,
      primaryLabel: l10n.onboardingContinue,
      primaryEnabled: answer != null,
      primaryLoading: _saving,
      onPrimary: _submitPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OmniOptionGroup<bool>(
            semanticLabel: l10n.onboardingAllergiesTitle,
            value: answer,
            options: [
              OmniOption(
                value: true,
                label: l10n.onboardingYes,
                icon: Icons.check_circle_outline_rounded,
              ),
              OmniOption(
                value: false,
                label: l10n.onboardingAllergiesNo,
                icon: Icons.block_rounded,
              ),
            ],
            onChanged: (value) {
              if (!value) _clearAllergies();
              setState(() {
                _hasAllergies = value;
                _validationMessage = null;
              });
            },
          ),
          if (answer == true) ...[
            const SizedBox(height: OmniSpacing.xl),
            for (var index = 0; index < _allergyNameControllers.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: OmniSpacing.base),
                child: _allergyCard(index, l10n),
              ),
            _DashedAddButton(
              label: l10n.onboardingAllergyAdd,
              onTap: () {
                setState(() {
                  _addAllergyFields();
                });
              },
            ),
          ],
          _inlineError(),
        ],
      ),
    );
  }

  Widget _allergyCard(int index, OmniLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.base,
        OmniSpacing.sm,
        OmniSpacing.xs,
        OmniSpacing.base,
      ),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.onboardingAllergyCardTitle(index + 1),
                  style: const TextStyle(
                    fontFamily: _bundledFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textPrimary,
                  ),
                ),
              ),
              if (_allergyNameControllers.length > 1)
                OmniPressable(
                  borderRadius: 22,
                  builder: (context, states) => IconButton(
                    statesController: states,
                    tooltip: l10n.onboardingAllergyRemove(index + 1),
                    onPressed: () => _removeAllergyFields(index),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    color: OmniColors.textSecondary,
                    icon: const Icon(Icons.close_rounded),
                  ),
                )
              else
                const SizedBox(height: 44),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: OmniSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OmniTextField(
                  label: l10n.onboardingAllergyName,
                  controller: _allergyNameControllers[index],
                  maxLength: 160,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {
                    _validationMessage = null;
                  }),
                ),
                const SizedBox(height: OmniSpacing.base),
                Text(
                  l10n.onboardingAllergySeverity,
                  style: const TextStyle(
                    fontFamily: _bundledFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: OmniColors.textPrimary,
                  ),
                ),
                const SizedBox(height: OmniSpacing.sm),
                OmniSegmentedChoice<String>(
                  semanticLabel: l10n.onboardingAllergySeverity,
                  value: _allergySeverities[index],
                  options: [
                    OmniChoiceOption(
                      value: 'légère',
                      label: l10n.onboardingSeverityMild,
                    ),
                    OmniChoiceOption(
                      value: 'modérée',
                      label: l10n.onboardingSeverityModerate,
                    ),
                    OmniChoiceOption(
                      value: 'sévère',
                      label: l10n.onboardingSeveritySevere,
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _allergySeverities[index] = value),
                ),
                const SizedBox(height: OmniSpacing.md),
                _LifeThreateningSwitch(
                  title: l10n.onboardingAllergyLifeThreatening,
                  subtitle: l10n.onboardingAllergyLifeThreateningHint,
                  value: _allergyLifeSafety[index],
                  onChanged: (value) {
                    setState(() {
                      _allergyLifeSafety[index] = value;
                      _validationMessage = null;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 3 « Maladies » (step 6) ────────────────────────────────────────

  Widget _buildConditionsPage(
    UserOnboardingProvider provider,
    OmniLocalizations l10n,
  ) {
    final answer =
        _hasConditions ?? (provider.chronicConditions.isNotEmpty ? true : null);
    return OnboardingFrame(
      progress: _progressFor(6),
      previousProgress: _progressFor(5),
      title: l10n.onboardingConditionsTitle,
      subtitle: l10n.onboardingConditionsSubtitle,
      onBack: _previousPage,
      onSkip: _skip,
      primaryLabel: l10n.onboardingContinue,
      primaryEnabled: answer != null,
      primaryLoading: _saving,
      onPrimary: _submitPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OmniOptionGroup<bool>(
            semanticLabel: l10n.onboardingConditionsTitle,
            value: answer,
            options: [
              OmniOption(
                value: true,
                label: l10n.onboardingYes,
                icon: Icons.check_circle_outline_rounded,
              ),
              OmniOption(
                value: false,
                label: l10n.onboardingNo,
                icon: Icons.block_rounded,
              ),
            ],
            onChanged: (value) {
              if (!value) {
                // « Non » = empty selection, as before.
                for (final condition in List.of(provider.chronicConditions)) {
                  provider.removeChronicCondition(condition);
                }
              }
              setState(() {
                _hasConditions = value;
                _validationMessage = null;
              });
            },
          ),
          if (answer == true) ...[
            const SizedBox(height: OmniSpacing.xl),
            OmniTextField(
              label: l10n.onboardingConditionsSearch,
              controller: _searchController,
              hintText: l10n.onboardingConditionsSearch,
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: _filterConditions,
            ),
            if (provider.chronicConditions.isNotEmpty) ...[
              const SizedBox(height: OmniSpacing.base),
              Wrap(
                spacing: OmniSpacing.sm,
                runSpacing: OmniSpacing.sm,
                children: [
                  for (final condition in provider.chronicConditions)
                    _RemovableChip(
                      label: onboardingConditionLabel(condition, l10n),
                      semanticLabel: l10n.onboardingConditionRemove(
                        onboardingConditionLabel(condition, l10n),
                      ),
                      onRemove: () {
                        provider.removeChronicCondition(condition);
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: OmniSpacing.base),
            if (_filteredConditions.isEmpty)
              Text(
                l10n.onboardingConditionsNoMatch,
                style: const TextStyle(
                  fontFamily: _bundledFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: OmniColors.textSecondary,
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(OmniRadii.card),
                  border: Border.all(color: OmniColors.borderLight),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < _filteredConditions.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: OmniColors.borderLight),
                      _CheckRow(
                        label: onboardingConditionLabel(
                          _filteredConditions[i],
                          l10n,
                        ),
                        checked: provider.chronicConditions.contains(
                          _filteredConditions[i],
                        ),
                        onTap: () {
                          final condition = _filteredConditions[i];
                          if (provider.chronicConditions.contains(condition)) {
                            provider.removeChronicCondition(condition);
                          } else {
                            provider.addChronicCondition(condition);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
          ],
          _inlineError(),
        ],
      ),
    );
  }

  // ── Page 4 « Médicaments » (step 7) ─────────────────────────────────────

  Widget _buildMedicationsPage(OmniLocalizations l10n) {
    final answer = _takesMedications;
    return OnboardingFrame(
      progress: _progressFor(7),
      previousProgress: _progressFor(6),
      title: l10n.onboardingMedicationsTitle,
      subtitle: l10n.onboardingMedicationsSubtitle,
      onBack: _previousPage,
      onSkip: _skip,
      primaryLabel: l10n.onboardingFinish,
      // « Oui » and « Non » both finish (CTO 2026-11-13, G2.1-A3b).
      primaryEnabled: answer != null,
      primaryLoading: _saving,
      onPrimary: _submitPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OmniOptionGroup<bool>(
            semanticLabel: l10n.onboardingMedicationsTitle,
            value: answer,
            options: [
              OmniOption(
                value: true,
                label: l10n.onboardingYes,
                icon: Icons.medication_outlined,
              ),
              OmniOption(
                value: false,
                label: l10n.onboardingMedicationsNo,
                icon: Icons.block_rounded,
              ),
            ],
            onChanged: (value) {
              setState(() {
                _takesMedications = value;
                _validationMessage = null;
              });
            },
          ),
          if (answer == true) ...[
            const SizedBox(height: OmniSpacing.xl),
            OnboardingNote(title: l10n.onboardingMedicationsInRecord),
          ],
          _inlineError(),
        ],
      ),
    );
  }
}

/// « Risque vital » row: title + subtitle + switch, one control for screen
/// readers, whole row tappable (≥ 56 px).
class _LifeThreateningSwitch extends StatelessWidget {
  const _LifeThreateningSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: OmniPressable(
        borderRadius: OmniRadii.field,
        builder: (context, states) => Material(
          color: OmniColors.slateSoft,
          borderRadius: BorderRadius.circular(OmniRadii.field),
          child: InkWell(
            statesController: states,
            borderRadius: BorderRadius.circular(OmniRadii.field),
            overlayColor: OmniPressable.overlay(OmniColors.textPrimary),
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OmniSpacing.md,
                vertical: OmniSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: _bundledFont,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OmniColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: _bundledFont,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: OmniColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: OmniSpacing.sm),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « Ajouter une allergie »: dashed deepTeal outline, full width, 52 px.
class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const double _radius = 14;

  @override
  Widget build(BuildContext context) {
    return OmniPressable(
      borderRadius: _radius,
      builder: (context, states) => CustomPaint(
        painter: const _DashedBorderPainter(radius: _radius),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            statesController: states,
            onTap: onTap,
            borderRadius: BorderRadius.circular(_radius),
            overlayColor: OmniPressable.overlay(OmniColors.deepTeal),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.base,
                    vertical: OmniSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: OmniColors.deepTeal,
                      ),
                      const SizedBox(width: OmniSpacing.sm),
                      Flexible(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontFamily: _bundledFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: OmniColors.deepTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.radius});

  final double radius;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = OmniColors.deepTeal
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.75),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.radius != radius;
}

/// Selected condition chip; a tap removes it (announced « Retirer : … »).
class _RemovableChip extends StatelessWidget {
  const _RemovableChip({
    required this.label,
    required this.semanticLabel,
    required this.onRemove,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: OmniPressable(
        borderRadius: OmniRadii.pill,
        builder: (context, states) => Material(
          color: OmniColors.mintSoft,
          shape: const StadiumBorder(
            side: BorderSide(color: OmniColors.deepTeal),
          ),
          child: InkWell(
            statesController: states,
            customBorder: const StadiumBorder(),
            overlayColor: OmniPressable.overlay(OmniColors.deepTeal),
            onTap: onRemove,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: _bundledFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: OmniColors.deepTeal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: OmniColors.deepTeal,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the conditions checkbox list (≥ 52 px, whole row tappable).
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: OmniPressable(
        borderRadius: 0,
        builder: (context, states) => Material(
          color: checked ? OmniColors.mintSoft : OmniColors.surfacePrimary,
          child: InkWell(
            statesController: states,
            overlayColor: OmniPressable.overlay(OmniColors.deepTeal),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniSpacing.base,
                  vertical: OmniSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: _bundledFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: OmniColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: OmniSpacing.md),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: checked
                            ? OmniColors.deepTeal
                            : OmniColors.surfacePrimary,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: checked
                              ? OmniColors.deepTeal
                              : OmniColors.borderStrong,
                          width: 2,
                        ),
                      ),
                      child: checked
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: OmniColors.textOnDark,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
