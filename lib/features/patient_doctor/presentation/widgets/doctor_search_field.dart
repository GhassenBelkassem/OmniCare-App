import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';

/// Compact search field for the doctor directory.
///
/// Reuses the exact same visual pattern as [ClinicSearchField]: thin neutral
/// border, mint focus state, search prefix icon, clear action.
class DoctorSearchField extends StatefulWidget {
  const DoctorSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<DoctorSearchField> createState() => _DoctorSearchFieldState();
}

class _DoctorSearchFieldState extends State<DoctorSearchField> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_syncClear);
  }

  @override
  void didUpdateWidget(DoctorSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncClear);
      widget.controller.addListener(_syncClear);
      _syncClear();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncClear);
    super.dispose();
  }

  void _syncClear() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [OmniColors.shadowSearch],
      ),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher un médecin',
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 22,
            color: OmniColors.textSecondary,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  tooltip: 'Effacer',
                  onPressed: _clear,
                  icon: const Icon(
                    Icons.cancel_rounded,
                    size: 20,
                    color: OmniColors.textTertiary,
                  ),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.base,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: OmniColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: OmniColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: OmniColors.freshMint,
              width: 1.5,
            ),
          ),
          filled: true,
          fillColor: OmniColors.surfacePrimary,
        ),
      ),
    );
  }
}
