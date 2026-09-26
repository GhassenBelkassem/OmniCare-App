import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OmniCare patient-app design system.
///
/// Core visual rules:
/// - Pure white is the main application canvas.
/// - #1FBF9A is the recognizable OmniCare brand mint. It is reserved for
///   semantic brand moments (selection, accepting requests, success, active
///   indicators). It is NOT the default color for generic icons, cards,
///   placeholders or informational panels.
/// - High-emphasis CTAs use the darker action teal (#0F826D) so white text
///   remains clearly readable. Never put white text on bright mint.
/// - Every supporting color (blue / cyan / violet / amber / slate) carries a
///   documented semantic role. Never pick a color just because it "looks nice".
/// - Gray/slate is used for structural, secondary and neutral iconography.
abstract final class OmniColors {
  // ─────────────────────────────────────────────────────────
  // MINT — BRAND / POSITIVE
  // ─────────────────────────────────────────────────────────

  /// OmniCare brand mint.
  ///
  /// Use ONLY for meaningfully brand-driven moments:
  /// - selection / selected state
  /// - accepting requests / availability
  /// - success
  /// - active indicators
  ///
  /// Do NOT use mint as the default color for generic icons, cards,
  /// placeholders, search fields or informational panels.
  static const freshMint = Color(0xFF1FBF9A);

  /// Soft mint support surface for selected/positive states.
  static const mintSoft = Color(0xFFEDFBF6);

  // ─────────────────────────────────────────────────────────
  // ACTION TEAL — PRIMARY CTA
  // ─────────────────────────────────────────────────────────

  /// Primary high-emphasis transactional CTA.
  ///
  /// Darker than [freshMint] so white button text stays readable:
  /// - Continue
  /// - Apply filters
  /// - Select this clinic
  /// - Submit / Confirm
  static const primaryAction = Color(0xFF0F826D);

  /// Pressed state for primary high-emphasis actions.
  static const primaryActionPressed = Color(0xFF0C6F5F);

  /// Deep supporting teal.
  ///
  /// Readable text/icon color over light surfaces.
  static const deepTeal = Color(0xFF176B5B);

  static const deepTealHover = Color(0xFF12594C);

  /// Strong dark teal used for contrast and text over mint.
  static const deepTealActive = Color(0xFF0D473D);

  // ─────────────────────────────────────────────────────────
  // BLUE — INFORMATION / LOCATION / GUIDANCE
  // ─────────────────────────────────────────────────────────

  /// Location pins, informational context and guidance.
  static const infoBlue = Color(0xFF2563EB);

  /// Stronger blue for emphasis/hover on informational elements.
  static const infoBlueStrong = Color(0xFF1D4ED8);

  /// Soft blue informational surface/panel background.
  static const infoBlueSoft = Color(0xFFEFF6FF);

  // ─────────────────────────────────────────────────────────
  // CYAN — CLINICAL / HEALTH DATA / MEDICAL SERVICES
  // ─────────────────────────────────────────────────────────

  /// Medical services, health data and clinical information icons.
  static const clinicalCyan = Color(0xFF0E7490);

  /// Soft cyan support surface for clinical/service icons.
  static const clinicalCyanSoft = Color(0xFFECFEFF);

  // ─────────────────────────────────────────────────────────
  // VIOLET — IDENTITY / SPECIALTIES / RECORDS
  // ─────────────────────────────────────────────────────────

  /// Identity, profile/family treatment, specialty chips, and future
  /// records/documents. Never paint a large page area violet.
  static const violet = Color(0xFF6941C6);

  /// Soft violet support surface for identity avatars and specialty chips.
  static const violetSoft = Color(0xFFF4F3FF);

  // ─────────────────────────────────────────────────────────
  // AMBER — PENDING / WARNING / NOT ACCEPTING
  // ─────────────────────────────────────────────────────────

  /// Not accepting requests, waiting, pending and attention states.
  /// Never used decoratively.
  static const amber = Color(0xFFB54708);

  /// Soft amber support surface.
  static const amberSoft = Color(0xFFFFFAEB);

  // ─────────────────────────────────────────────────────────
  // CORAL — URGENT / HIGH ATTENTION
  // ─────────────────────────────────────────────────────────

  /// Urgent-care and high-attention non-error situations only.
  /// Added for future Request screens; not used on Pages 01–03.
  static const urgentCoral = Color(0xFFC4320A);

  static const urgentCoralSoft = Color(0xFFFFF4ED);

  // ─────────────────────────────────────────────────────────
  // RED — ERROR / DESTRUCTIVE
  // ─────────────────────────────────────────────────────────

  /// Errors, failures and destructive actions ONLY.
  static const error = Color(0xFFD92D20);

  /// Soft error support surface.
  static const errorSoft = Color(0xFFFEF3F2);

  // ─────────────────────────────────────────────────────────
  // SLATE — STRUCTURAL / NAVIGATION / NEUTRAL ICONOGRAPHY
  // ─────────────────────────────────────────────────────────

  /// Structural navigation icons, secondary professional information and
  /// neutral illustration fallbacks. Replaces mint where mint had no meaning.
  static const slateBlue = Color(0xFF294B63);

  /// Soft slate surface for neutral placeholders, fallbacks and shells.
  static const slateSoft = Color(0xFFF2F7FA);

  // ─────────────────────────────────────────────────────────
  // NEUTRAL / CANVAS
  // ─────────────────────────────────────────────────────────

  /// Main patient application canvas. White remains the primary canvas.
  static const pageBackground = Colors.white;

  static const surfacePrimary = Colors.white;

  /// Neutral soft secondary surface (chip shells, structural circles).
  ///
  /// This is intentionally slate-tinted neutral — not mint — so generic
  /// panels and placeholders never look like success/availability.
  static const surfaceSecondary = slateSoft;

  // ─────────────────────────────────────────────────────────
  // Text
  // ─────────────────────────────────────────────────────────

  static const textPrimary = Color(0xFF1D2939);

  static const textSecondary = Color(0xFF667085);

  static const textTertiary = Color(0xFF98A2B3);

  static const textDisabled = Color(0xFFD0D5DD);

  static const textOnDark = Colors.white;

  /// Recommended text/icon color over bright [freshMint].
  ///
  /// Dark teal instead of white so the mint moment stays readable.
  static const textOnMint = deepTealActive;

  // ─────────────────────────────────────────────────────────
  // Borders
  // ─────────────────────────────────────────────────────────

  static const borderLight = Color(0xFFE4E7EC);

  static const borderStrong = Color(0xFFD0D5DD);

  /// Focus/selection should visibly belong to OmniCare. Brand interaction.
  static const borderFocus = freshMint;

  // ─────────────────────────────────────────────────────────
  // Semantic aliases
  // ─────────────────────────────────────────────────────────

  /// Positive/success state — brand mint.
  static const success = freshMint;

  /// Subtle positive/success support surface.
  static const successSubtle = mintSoft;

  /// Warning/pending/not-accepting state — amber.
  static const warning = amber;

  /// Subtle warning support surface.
  static const warningSubtle = amberSoft;

  // ─────────────────────────────────────────────────────────
  // Shadows
  // ─────────────────────────────────────────────────────────

  /// Use shadows very sparingly.
  static const shadowSm = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const shadowMd = BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 14,
    offset: Offset(0, 4),
  );

  /// Premium card elevation for clinic directory cards.
  ///
  /// Visible but restrained: enough to separate cards from the white canvas
  /// without looking heavy or dated.
  static const shadowCard = BoxShadow(
    color: Color(0x140F172A),
    blurRadius: 18,
    offset: Offset(0, 6),
  );

  /// Subtle shadow for search field and similar elevated inputs.
  ///
  /// Slightly more visible than before — lifts the field from the flat canvas
  /// while keeping a clean, premium feel.
  static const shadowSearch = BoxShadow(
    color: Color(0x0F0F172A),
    blurRadius: 14,
    offset: Offset(0, 4),
  );
}

abstract final class OmniSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  static const double pageHorizontal = 20;
  static const double pageVertical = 24;
}

abstract final class OmniRadii {
  static const double field = 12;
  static const double card = 16;
  static const double cardLarge = 20;
  static const double sheet = 24;
  static const double pill = 999;
}

/// Shared style for high-emphasis green actions.
///
/// Enabled and pressed buttons always use white labels/icons. Disabled
/// controls intentionally use the neutral disabled surface and text colors.
ButtonStyle buildOmniPrimaryButtonStyle() {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 50)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: OmniSpacing.base, vertical: 14),
    ),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return OmniColors.borderLight;
      }
      if (states.contains(WidgetState.pressed)) {
        return OmniColors.primaryActionPressed;
      }
      return OmniColors.primaryAction;
    }),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? OmniColors.textTertiary
          : Colors.white,
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.pressed)
          ? Colors.white.withValues(alpha: 0.06)
          : null,
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    ),
  );
}

/// Builds the shared OmniCare Material 3 patient theme.
///
/// Semantic hierarchy (the color system lives here):
///
/// freshMint            → brand, selection, accepting, success, active
/// primaryAction        → Continue / Apply filters / Select / Submit
/// infoBlue             → location, informational panels, guidance
/// clinicalCyan         → medical services, health data, clinical info
/// violet               → identity, specialties, records/documents
/// amber                → pending, warning, not accepting requests
/// urgentCoral          → urgent / high-attention (future Request screens)
/// error                → errors, destructive actions
/// slateBlue / slateSoft→ structural navigation, placeholders, neutral icon
/// white                → main patient canvas
///
/// Do not use [OmniColors.freshMint] as the default for generic icons,
/// cards, placeholders or informational panels.
ThemeData buildOmniTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: OmniColors.freshMint,
    brightness: Brightness.light,

    // MINT = brand/selection/accepting. Text over mint uses the deep
    // readable teal, never white. Primary action buttons override this pair
    // through [buildOmniPrimaryButtonStyle].
    primary: OmniColors.freshMint,
    onPrimary: OmniColors.textOnMint,

    // Slate = structural/secondary professional information.
    secondary: OmniColors.slateBlue,
    onSecondary: OmniColors.textOnDark,

    // Violet = identity/specialties (Material tertiary only; use the explicit
    // semantic tokens for violet treatment).
    tertiary: OmniColors.violet,
    onTertiary: Colors.white,

    surface: OmniColors.surfacePrimary,
    onSurface: OmniColors.textPrimary,

    error: OmniColors.error,
    onError: Colors.white,
  );

  final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
    ThemeData.light().textTheme,
  );

  final textTheme = baseTextTheme.apply(
    bodyColor: OmniColors.textPrimary,
    displayColor: OmniColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,

    colorScheme: colorScheme,

    // ─────────────────────────────────────────────────────
    // Canvas
    // ─────────────────────────────────────────────────────
    scaffoldBackgroundColor: OmniColors.pageBackground,
    canvasColor: OmniColors.surfacePrimary,
    cardColor: OmniColors.surfacePrimary,

    // ─────────────────────────────────────────────────────
    // Typography
    // ─────────────────────────────────────────────────────
    textTheme: textTheme,

    // ─────────────────────────────────────────────────────
    // App bar
    // ─────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: OmniColors.surfacePrimary,
      foregroundColor: OmniColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: OmniColors.textPrimary,
        letterSpacing: -0.25,
      ),
    ),

    // ─────────────────────────────────────────────────────
    // Primary CTA
    // ─────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: buildOmniPrimaryButtonStyle(),
    ),

    // FilledButton is used throughout Patient, Security and Request flows.
    // Mirror the primary CTA contract instead of falling back to the seed
    // color's foreground, which previously produced gray/dark labels.
    filledButtonTheme: FilledButtonThemeData(
      style: buildOmniPrimaryButtonStyle(),
    ),

    // ─────────────────────────────────────────────────────
    // Secondary / outlined actions
    // ─────────────────────────────────────────────────────
    //
    // Neutral slate outline, not mint: secondary/quiet actions (Reset,
    // Change…) must never compete with the primary CTA.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 50)),

        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: OmniSpacing.base, vertical: 14),
        ),

        foregroundColor: const WidgetStatePropertyAll(OmniColors.slateBlue),

        backgroundColor: const WidgetStatePropertyAll(Colors.white),

        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return OmniColors.slateBlue.withValues(alpha: 0.06);
          }

          return null;
        }),

        side: const WidgetStatePropertyAll(
          BorderSide(color: OmniColors.borderStrong, width: 1.25),
        ),

        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),

        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
    ),

    // ─────────────────────────────────────────────────────
    // Quiet / tertiary actions
    // ─────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: OmniColors.deepTeal,
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ─────────────────────────────────────────────────────
    // Inputs
    // ─────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OmniColors.surfacePrimary,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.base,
        vertical: 14,
      ),

      hintStyle: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 15,
        color: OmniColors.textTertiary,
      ),

      labelStyle: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        color: OmniColors.textSecondary,
      ),

      floatingLabelStyle: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        color: OmniColors.deepTeal,
        fontWeight: FontWeight.w600,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OmniRadii.field),
        borderSide: const BorderSide(color: OmniColors.borderLight),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OmniRadii.field),
        borderSide: const BorderSide(color: OmniColors.borderLight),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OmniRadii.field),
        borderSide: const BorderSide(color: OmniColors.freshMint, width: 1.75),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OmniRadii.field),
        borderSide: const BorderSide(color: OmniColors.error),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OmniRadii.field),
        borderSide: const BorderSide(color: OmniColors.error, width: 1.75),
      ),
    ),

    // ─────────────────────────────────────────────────────
    // Dividers
    // ─────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: OmniColors.borderLight,
      thickness: 1,
      space: 0,
    ),

    // ─────────────────────────────────────────────────────
    // Progress
    // ─────────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: OmniColors.freshMint,
    ),

    // ─────────────────────────────────────────────────────
    // Radio
    // ─────────────────────────────────────────────────────
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return OmniColors.freshMint;
        }

        return OmniColors.textTertiary;
      }),
    ),

    // ─────────────────────────────────────────────────────
    // Checkbox
    // ─────────────────────────────────────────────────────
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return OmniColors.freshMint;
        }

        return Colors.transparent;
      }),

      checkColor: const WidgetStatePropertyAll(OmniColors.deepTealActive),

      side: const BorderSide(color: OmniColors.borderStrong),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    // ─────────────────────────────────────────────────────
    // Bottom sheets
    // ─────────────────────────────────────────────────────
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: OmniColors.surfacePrimary,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: OmniColors.surfacePrimary,

      modalBarrierColor: Color(0x59000000),

      showDragHandle: true,
      dragHandleColor: OmniColors.borderStrong,

      elevation: 0,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(OmniRadii.sheet),
        ),
      ),
    ),

    // ─────────────────────────────────────────────────────
    // Dialogs
    // ─────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: OmniColors.surfacePrimary,
      surfaceTintColor: Colors.transparent,

      elevation: 8,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
      ),
    ),

    // ─────────────────────────────────────────────────────
    // Chips
    // ─────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: OmniColors.surfaceSecondary,

      selectedColor: OmniColors.mintSoft,

      disabledColor: OmniColors.surfaceSecondary,

      labelStyle: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: OmniColors.textPrimary,
      ),

      secondaryLabelStyle: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: OmniColors.deepTeal,
      ),

      side: const BorderSide(color: OmniColors.borderLight),

      shape: const StadiumBorder(),

      padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.sm),
    ),

    // ─────────────────────────────────────────────────────
    // Interaction feedback
    // ─────────────────────────────────────────────────────
    splashColor: OmniColors.freshMint.withValues(alpha: 0.08),

    highlightColor: OmniColors.freshMint.withValues(alpha: 0.04),

    focusColor: OmniColors.freshMint.withValues(alpha: 0.12),

    hoverColor: OmniColors.freshMint.withValues(alpha: 0.04),
  );
}

/// Convenience extension for OmniCare theme access.
extension OmniThemeExtension on BuildContext {
  ColorScheme get ocColors => Theme.of(this).colorScheme;

  TextTheme get ocText => Theme.of(this).textTheme;
}
