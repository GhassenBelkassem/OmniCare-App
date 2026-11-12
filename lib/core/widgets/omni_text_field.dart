import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/omni_theme.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// OmniCare form field with its label ABOVE the input (G3 auth redesign).
///
/// Pure UI: it wraps a [TextFormField], so the screen keeps its own
/// controller, validator and [Form]. The decoration is built here from the
/// Omni tokens; the global `inputDecorationTheme` is not changed.
///
/// States:
/// * normal: 1 px [OmniColors.borderLight], focus [OmniColors.freshMint] 1.75;
/// * error: the validator's message below the field, [OmniColors.error];
/// * success ([isSuccess]): [OmniColors.freshMint] border, a check icon and
///   the optional [successText] in [OmniColors.deepTeal];
/// * helper: [helperText] below the field in [OmniColors.textSecondary].
class OmniTextField extends StatelessWidget {
  const OmniTextField({
    super.key,
    required this.label,
    this.fieldKey,
    this.controller,
    this.validator,
    this.hintText,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.autovalidateMode,
    this.onChanged,
    this.onFieldSubmitted,
    this.focusNode,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
    this.helperText,
    this.successText,
    this.isSuccess = false,
  });

  /// Text shown above the field (14 w600).
  final String label;

  /// Key given to the inner [TextFormField] (tests find fields by key).
  final Key? fieldKey;

  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final String? hintText;

  /// Leading icon (e.g. `Icons.email_outlined`).
  final IconData? prefixIcon;

  /// Leading segment text (e.g. « +216 ») on a slate background.
  final String? prefixText;

  /// Trailing widget, e.g. the eye toggle [IconButton] built by the screen.
  final Widget? suffix;

  /// Maximum length; no counter is shown.
  final int? maxLength;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final AutovalidateMode? autovalidateMode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  /// Neutral hint below the field. Hidden while an error is shown.
  final String? helperText;

  /// Message shown below the field in the success state.
  final String? successText;

  /// Success state decided by the screen (e.g. passwords match).
  final bool isSuccess;

  static const double _labelGap = 6;
  static const double _iconSize = 20;

  static OutlineInputBorder _border(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(OmniRadii.field),
        borderSide: BorderSide(color: color, width: width),
      );

  static const TextStyle _messageStyle = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).inputDecorationTheme;
    final restColor = isSuccess ? OmniColors.freshMint : OmniColors.borderLight;
    final restWidth = isSuccess ? 1.75 : 1.0;
    final belowText = isSuccess ? (successText ?? helperText) : helperText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: _bundledFont,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: OmniColors.textPrimary,
          ),
        ),
        const SizedBox(height: _labelGap),
        TextFormField(
          key: fieldKey,
          controller: controller,
          validator: validator,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          obscureText: obscureText,
          autovalidateMode: autovalidateMode,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontFamily: _bundledFont,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: OmniColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: OmniColors.textTertiary,
            ),
            filled: true,
            fillColor: OmniColors.surfacePrimary,
            contentPadding: theme.contentPadding,
            counterText: '',
            prefixIcon: _buildPrefix(),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon: _buildSuffix(),
            helperText: belowText,
            helperMaxLines: 3,
            helperStyle: _messageStyle.copyWith(
              color: isSuccess ? OmniColors.deepTeal : OmniColors.textSecondary,
              fontWeight: isSuccess ? FontWeight.w600 : FontWeight.w500,
            ),
            errorMaxLines: 3,
            errorStyle: _messageStyle.copyWith(color: OmniColors.error),
            border: _border(restColor, restWidth),
            enabledBorder: _border(restColor, restWidth),
            disabledBorder: _border(OmniColors.borderLight, 1),
            focusedBorder: _border(OmniColors.freshMint, 1.75),
            errorBorder: _border(OmniColors.error, 1),
            focusedErrorBorder: _border(OmniColors.error, 1.75),
          ),
        ),
      ],
    );
  }

  Widget? _buildPrefix() {
    final icon = prefixIcon == null
        ? null
        : Icon(prefixIcon, size: _iconSize, color: OmniColors.textSecondary);
    final segmentText = prefixText;
    if (segmentText == null) return icon;

    return _PrefixSegment(icon: icon, text: segmentText);
  }

  Widget? _buildSuffix() {
    if (!isSuccess) return suffix;
    const check = Icon(
      Icons.check_circle_rounded,
      size: _iconSize,
      color: OmniColors.deepTeal,
    );
    if (suffix == null) return check;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [check, suffix!],
    );
  }
}

/// Leading « +216 » style segment: slate background with a right divider.
class _PrefixSegment extends StatelessWidget {
  const _PrefixSegment({required this.icon, required this.text});

  final Widget? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 1, top: 1, bottom: 1, right: 10),
      padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: const BoxDecoration(
        color: OmniColors.slateSoft,
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(OmniRadii.field - 1),
        ),
        border: Border(right: BorderSide(color: OmniColors.borderLight)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: OmniSpacing.xs)],
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontFamily: _bundledFont,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: OmniColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
