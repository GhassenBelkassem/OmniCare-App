import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:provider/provider.dart';

import '../../core/l10n/blood_type_label.dart';
import '../../core/models/blood_type.dart';
import '../../core/theme/omni_theme.dart';
import '../../core/widgets/omni_pressable.dart';
import '../../l10n/omni_localizations.dart';
import '../../providers/user_onboarding_provider.dart';
import 'onboarding_labels.dart';
import 'widgets/onboarding_summary_list.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// End of onboarding (G3-ONB2): check « pop », « Vos informations sont
/// enregistrées », a summary of the values already in memory
/// ([UserOnboardingProvider]) and « Accéder à mon espace » (same
/// navigation to /home as before). The QR code, the confetti and the demo
/// button are gone.
///
/// A row is shown only when its value is available. Lists (allergies,
/// conditions) are shown only when not empty: an empty list in memory can
/// also mean « saved in an earlier session », so it is never shown as
/// « none ».
class OnboardingCompleteScreen extends StatefulWidget {
  const OnboardingCompleteScreen({super.key});

  @override
  State<OnboardingCompleteScreen> createState() =>
      _OnboardingCompleteScreenState();
}

class _OnboardingCompleteScreenState extends State<OnboardingCompleteScreen>
    with SingleTickerProviderStateMixin {
  static const double _maxContentWidth = 480;
  static const double _buttonRadius = 14;

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _pop,
    curve: Curves.easeOutBack,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _pop.value = 1;
    } else {
      _pop.forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  List<OnboardingSummaryItem> _items(
    UserOnboardingProvider provider,
    OmniLocalizations l10n,
  ) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = '${provider.firstName ?? ''} ${provider.lastName ?? ''}'
        .trim();
    final dateOfBirth = provider.dateOfBirth;
    final gender = (provider.gender ?? '').trim();
    final bloodType = BloodType.fromWire(provider.bloodGroup);
    final height = provider.heightCm;
    final weight = provider.weightKg;
    final allergies = provider.allergies
        .map((allergy) => allergy.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final conditions = provider.chronicConditions
        .map((condition) => onboardingConditionLabel(condition, l10n))
        .toList();
    return [
      if (name.isNotEmpty)
        OnboardingSummaryItem(label: l10n.onboardingSummaryName, value: name),
      if (dateOfBirth != null)
        OnboardingSummaryItem(
          label: l10n.onboardingBirthDate,
          value: DateFormat('dd/MM/yyyy').format(dateOfBirth),
        ),
      if (gender.isNotEmpty)
        OnboardingSummaryItem(
          label: l10n.onboardingGender,
          value: onboardingGenderLabel(gender, l10n),
        ),
      if (bloodType != null)
        OnboardingSummaryItem(
          label: l10n.onboardingSummaryBlood,
          value: bloodType.label(l10n),
        ),
      if (height != null)
        OnboardingSummaryItem(
          label: l10n.onboardingHeightLabel,
          value: '$height ${l10n.onboardingUnitCm}',
        ),
      if (weight != null)
        OnboardingSummaryItem(
          label: l10n.onboardingWeightLabel,
          value:
              '${NumberFormat('0.#', locale).format(weight)} '
              '${l10n.onboardingUnitKg}',
        ),
      if (allergies.isNotEmpty)
        OnboardingSummaryItem(
          label: l10n.onboardingSummaryAllergies,
          value: allergies.join(', '),
        ),
      if (conditions.isNotEmpty)
        OnboardingSummaryItem(
          label: l10n.onboardingSummaryConditions,
          value: conditions.join(', '),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserOnboardingProvider>(context);
    final l10n = OmniLocalizations.of(context);
    final items = _items(provider, l10n);

    return Scaffold(
      backgroundColor: OmniColors.surfacePrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = ((constraints.maxWidth - _maxContentWidth) / 2).clamp(
              OmniSpacing.pageHorizontal,
              double.infinity,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      side,
                      OmniSpacing.xxxl,
                      side,
                      OmniSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ScaleTransition(
                            scale: _scale,
                            child: const ExcludeSemantics(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: OmniColors.mintSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox.square(
                                  dimension: 96,
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 52,
                                    color: OmniColors.deepTeal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: OmniSpacing.xl),
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.onboardingDoneTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: _bundledFont,
                              fontSize: 26,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: OmniColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: OmniSpacing.sm),
                        Text(
                          l10n.onboardingDoneBody,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: _bundledFont,
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: OmniColors.textSecondary,
                          ),
                        ),
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: OmniSpacing.xl),
                          OnboardingSummaryList(items: items),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    side,
                    OmniSpacing.sm,
                    side,
                    OmniSpacing.base,
                  ),
                  child: OmniPressable(
                    borderRadius: _buttonRadius,
                    builder: (context, states) => ElevatedButton(
                      statesController: states,
                      onPressed: OmniPressable.withHaptic(() {
                        Navigator.pushReplacementNamed(context, '/home');
                      }),
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(
                          Size.fromHeight(52),
                        ),
                        elevation: const WidgetStatePropertyAll(0),
                        backgroundColor: const WidgetStatePropertyAll(
                          OmniColors.primaryAction,
                        ),
                        foregroundColor: const WidgetStatePropertyAll(
                          OmniColors.textOnDark,
                        ),
                        shape: const WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(_buttonRadius),
                            ),
                          ),
                        ),
                        overlayColor: OmniPressable.overlay(
                          OmniColors.textOnDark,
                        ),
                      ),
                      child: Text(
                        l10n.onboardingDoneCta,
                        style: const TextStyle(
                          fontFamily: _bundledFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
