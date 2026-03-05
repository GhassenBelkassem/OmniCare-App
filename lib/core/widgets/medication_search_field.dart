import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/medications_api.dart';

class MedicationSearchField extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController? dosageController;
  final String hintText;
  final MedicationsApi api;
  final ValueChanged<MedicationSearchResult>? onSelected;
  final ValueChanged<String>? onChanged;

  MedicationSearchField({
    super.key,
    required this.controller,
    this.dosageController,
    required this.hintText,
    MedicationsApi? api,
    this.onSelected,
    this.onChanged,
  }) : api = api ?? MedicationsApi();

  @override
  State<MedicationSearchField> createState() => _MedicationSearchFieldState();
}

class _MedicationSearchFieldState extends State<MedicationSearchField> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  Timer? _blurTimer;
  bool _isPicking = false;

  bool _loading = false;
  List<MedicationSearchResult> _results = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _blurTimer?.cancel();
        _blurTimer = Timer(const Duration(milliseconds: 120), () {
          if (!mounted) return;
          if (_isPicking) return;
          setState(() {
            _results = const [];
            _loading = false;
          });
        });
      } else {
        _blurTimer?.cancel();
        _scheduleSearch(widget.controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MedicationSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    widget.onChanged?.call(widget.controller.text);
    if (_focusNode.hasFocus) {
      _scheduleSearch(widget.controller.text);
    }
  }

  void _scheduleSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final trimmed = q.trim();
      if (trimmed.isEmpty) {
        if (!mounted) return;
        setState(() {
          _results = const [];
          _loading = false;
        });
        return;
      }

      setState(() {
        _loading = true;
      });

      try {
        final next = await widget.api.searchTop10(trimmed);
        if (!mounted) return;
        setState(() {
          _results = next;
          _loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _results = const [];
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _debounce?.cancel();
    _blurTimer?.cancel();
    super.dispose();
  }

  void _pick(MedicationSearchResult r) {
    _isPicking = true;
    widget.controller.text = r.name;
    if (widget.dosageController != null) {
      final current = widget.dosageController!.text.trim();
      final next = (r.dosage ?? '').trim();
      if (current.isEmpty && next.isNotEmpty) {
        widget.dosageController!.text = next;
      }
    }

    widget.onSelected?.call(r);

    setState(() {
      _results = const [];
    });

    _focusNode.unfocus();
    _isPicking = false;
  }

  @override
  Widget build(BuildContext context) {
    final showResults = _focusNode.hasFocus && (_loading || _results.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF1D2939)),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF667085)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
            ),
          ),
        ),
        if (showResults) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Recherche...'),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final r = _results[index];
                      final subtitleParts = <String>[];
                      final dosage = (r.dosage ?? '').trim();
                      final dci = (r.dci ?? '').trim();
                      if (dosage.isNotEmpty) subtitleParts.add(dosage);
                      if (dci.isNotEmpty) subtitleParts.add(dci);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _pick(r),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            r.name,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: subtitleParts.isEmpty
                              ? null
                              : Text(
                                  subtitleParts.join(' • '),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF667085)),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}
