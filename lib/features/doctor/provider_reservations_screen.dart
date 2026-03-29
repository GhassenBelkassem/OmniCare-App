import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/patients_api.dart';
import '../../core/api/reservations_api.dart';
import '../../core/models/patient_models.dart';

class ProviderReservationsScreen extends StatefulWidget {
  const ProviderReservationsScreen({super.key});

  @override
  State<ProviderReservationsScreen> createState() =>
      _ProviderReservationsScreenState();
}

class _ProviderReservationsScreenState extends State<ProviderReservationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ReservationsApi _api = ReservationsApi();
  final PatientsApi _patientsApi = PatientsApi();

  final Map<String, Set<int>> _selectedSlotKeysByRequestId = {};

  Future<List<Map<String, dynamic>>>? _pending;
  Future<List<Map<String, dynamic>>>? _proposed;
  Future<List<Map<String, dynamic>>>? _confirmed;

  Future<Map<String, String>>? _patientNameById;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  bool _hasAnyExactTimeIntent(Map<String, dynamic> rr) {
    final intents = (rr['intents'] is List)
        ? (rr['intents'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    for (final i in intents) {
      final exactTime = (i['exactTime'] ?? '').toString().trim();
      if (exactTime.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<PatientPassport?> _safeGetPatientPassport(String patientId) async {
    try {
      return await _patientsApi.getPatientPassportTyped(patientId);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        return null;
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAll() {
    setState(() {
      _pending = _api.listReservationRequests(status: 'PENDING');
      _proposed = _api.listReservationRequests(status: 'PROPOSED');
      _confirmed = _api.listReservationRequests(status: 'CONFIRMED');
      _patientNameById = _loadPatientNames();
    });
  }

  Future<Map<String, String>> _loadPatientNames() async {
    final list = await _patientsApi.getPatientsForProfessional();
    final m = <String, String>{};
    for (final p in list) {
      final id = p.patientId.trim();
      if (id.isEmpty) continue;
      m[id] = p.displayName.trim().isEmpty ? 'Patient' : p.displayName.trim();
    }
    return m;
  }

  DateTime? _parseIntentDateTime(Map<String, dynamic> i) {
    final d = (i['specificDate'] ?? '').toString().trim();
    final t = (i['exactTime'] ?? '').toString().trim();
    if (d.isEmpty || t.isEmpty) return null;
    final dateParts = d.split('-');
    if (dateParts.length != 3) return null;
    final timeParts = t.split(':');
    if (timeParts.length < 2) return null;
    final y = int.tryParse(dateParts[0]);
    final m = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    final hh = int.tryParse(timeParts[0]);
    final mm = int.tryParse(timeParts[1]);
    final ss = timeParts.length >= 3 ? int.tryParse(timeParts[2]) ?? 0 : 0;
    if (y == null || m == null || day == null || hh == null || mm == null) {
      return null;
    }
    return DateTime(y, m, day, hh, mm, ss);
  }

  String _fmtDateTime(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$min';
  }

  Set<int> _busySlotKeys(List<Map<String, dynamic>> confirmed) {
    final busy = <int>{};
    for (final rr in confirmed) {
      final slots = (rr['slots'] is List)
          ? (rr['slots'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: false)
          : const <Map<String, dynamic>>[];
      for (final s in slots) {
        final acceptedAt = (s['acceptedAt'] ?? '').toString().trim();
        if (acceptedAt.isEmpty) continue;
        final dtRaw = (s['dateTime'] ?? '').toString().trim();
        final parsed = DateTime.tryParse(dtRaw);
        if (parsed == null) continue;
        busy.add(
          DateTime(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
          ).millisecondsSinceEpoch,
        );
      }
    }
    return busy;
  }

  String _resolvePatientName(
    Map<String, dynamic> rr,
    Map<String, String> patientNames,
  ) {
    final fromPayload =
        <String?>[
              rr['patientName']?.toString(),
              rr['patientDisplayName']?.toString(),
              rr['patientFullName']?.toString(),
              rr['patient'] is Map
                  ? (rr['patient'] as Map)['displayName']?.toString()
                  : null,
              rr['patient'] is Map
                  ? (rr['patient'] as Map)['fullName']?.toString()
                  : null,
            ]
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);

    if (fromPayload.isNotEmpty) {
      return fromPayload.first;
    }

    final patientId = (rr['patientId'] ?? '').toString().trim();
    final mapped = (patientId.isEmpty) ? null : patientNames[patientId];
    if (mapped != null && mapped.trim().isNotEmpty) {
      return mapped.trim();
    }
    return 'Patient';
  }

  List<DateTime> _extractSuggestedSlots(Map<String, dynamic> rr) {
    final intents = (rr['intents'] is List)
        ? (rr['intents'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final suggested =
        intents
            .map(_parseIntentDateTime)
            .whereType<DateTime>()
            .map(
              (dt) => DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute),
            )
            .toSet()
            .toList(growable: false)
          ..sort();
    return suggested;
  }

  Future<void> _openRequestDetails(
    BuildContext context,
    Map<String, dynamic> rr, {
    required String patientName,
  }) async {
    final patientId = (rr['patientId'] ?? '').toString().trim();
    final requestId = (rr['id'] ?? '').toString().trim();
    final status = (rr['status'] ?? '').toString().trim();
    final reason = (rr['reason'] ?? '').toString().trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF4F5F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final Future<PatientPassport?> passportFuture = (patientId.isEmpty)
            ? Future.value(null)
            : _safeGetPatientPassport(patientId);
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.78,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Text(
                    patientName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Status: ${status.isEmpty ? '--' : status}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF667085),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        reason,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF1D2939),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Patient details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<PatientPassport?>(
                    future: passportFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            'Failed to load patient details',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: const Color(0xFF667085),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      final passport = snap.data;
                      if (passport == null) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            'No patient information available',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: const Color(0xFF667085),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      final rows = <Map<String, String>>[
                        if ((passport.fullName).trim().isNotEmpty)
                          {'Full name': passport.fullName.trim()},
                        if ((passport.phoneNumber ?? '').trim().isNotEmpty)
                          {'Phone': (passport.phoneNumber ?? '').trim()},
                        if ((passport.gender ?? '').trim().isNotEmpty)
                          {'Gender': (passport.gender ?? '').trim()},
                        if (passport.age != null)
                          {'Age': passport.age.toString()},
                        if ((passport.bloodGroup ?? '').trim().isNotEmpty)
                          {'Blood group': (passport.bloodGroup ?? '').trim()},
                      ];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final r in rows) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.keys.first,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: const Color(0xFF667085),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    r.values.first,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: const Color(0xFF1D2939),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Request details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request ID',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          requestId.isEmpty ? '--' : requestId,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF1D2939),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Suggested times',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _extractSuggestedSlots(rr)
                              .map(
                                (dt) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F4F7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Text(
                                    _fmtDateTime(dt),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF475467),
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _proposeSlots(
    BuildContext context,
    Map<String, dynamic> rr,
  ) async {
    final requestId = (rr['id'] ?? '').toString().trim();
    if (requestId.isEmpty) return;

    final picked = <DateTime>[];
    for (int i = 0; i < 3; i++) {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1FBF9A),
                primary: const Color(0xFF1FBF9A),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
      if (date == null) return;

      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1FBF9A),
                primary: const Color(0xFF1FBF9A),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
      if (time == null) return;

      picked.add(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    }

    try {
      await _api.proposeSlots(requestId: requestId, slots: picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Slots proposed', style: GoogleFonts.plusJakartaSans()),
        ),
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to propose slots: $e',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Widget _buildReservationCard(
    BuildContext context,
    Map<String, dynamic> rr, {
    required Map<String, String> patientNames,
    required Set<int> busyKeys,
  }) {
    final status = (rr['status'] ?? '').toString().trim();
    final patientName = _resolvePatientName(rr, patientNames).trim();
    final initials = patientName
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .take(2)
        .map((p) => p.trim()[0].toUpperCase())
        .join();

    final suggested = _extractSuggestedSlots(rr);

    final isExactRequest = _hasAnyExactTimeIntent(rr);
    final requiredSelectionCount = isExactRequest ? 1 : 3;

    final requestId = (rr['id'] ?? '').toString().trim();

    final slots = (rr['slots'] is List)
        ? (rr['slots'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final slotDts =
        slots
            .map(
              (s) => DateTime.tryParse((s['dateTime'] ?? '').toString().trim()),
            )
            .whereType<DateTime>()
            .map(
              (dt) => DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute),
            )
            .toList(growable: false)
          ..sort();

    final selectedKeys = _selectedSlotKeysByRequestId[requestId] ?? <int>{};
    final selectedDts = suggested
        .where((dt) => selectedKeys.contains(dt.millisecondsSinceEpoch))
        .toList(growable: false);

    Future<void> proposeSelectedOrSuggested() async {
      if (requestId.isEmpty) return;
      final selection = isExactRequest
          ? selectedDts
          : ((selectedDts.isNotEmpty) ? selectedDts : suggested);

      if (selection.length != requiredSelectionCount) {
        final selectedCount = selection.length;
        final remaining = (requiredSelectionCount - selectedCount).clamp(
          0,
          requiredSelectionCount,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remaining == 0
                  ? (requiredSelectionCount == 1
                        ? 'Please select exactly 1 suggested time to confirm.'
                        : 'Please select exactly 3 times to propose.')
                  : 'Please select $remaining more time${remaining == 1 ? '' : 's'} (selected $selectedCount/$requiredSelectionCount).',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }

      final List<DateTime> toSend = selection;

      final hasConflict = toSend.any(
        (dt) => busyKeys.contains(dt.millisecondsSinceEpoch),
      );
      if (hasConflict) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'One or more suggested times conflicts with your schedule.',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }
      try {
        await _api.proposeSlots(requestId: requestId, slots: toSend);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isExactRequest ? 'Appointment confirmed' : 'Sent proposal',
              style: GoogleFonts.plusJakartaSans(),
            ),
          ),
        );
        setState(() {
          _selectedSlotKeysByRequestId.remove(requestId);
        });
        _loadAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to propose: $e',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _openRequestDetails(
              context,
              rr,
              patientName: patientName.isEmpty ? 'Patient' : patientName,
            ),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1FBF9A).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials.isEmpty ? 'P' : initials,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1FBF9A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName.isEmpty ? 'Patient' : patientName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1D2939),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to view details',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1FBF9A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.isEmpty ? '--' : status,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1FBF9A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Suggested times',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 10),
          if (suggested.isEmpty)
            Text(
              'No exact times provided',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF667085),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: suggested
                  .map((dt) {
                    final key = dt.millisecondsSinceEpoch;
                    final isBusy = busyKeys.contains(key);
                    final isSelected = selectedKeys.contains(key);
                    return InkWell(
                      onTap: isBusy
                          ? null
                          : () {
                              setState(() {
                                final set = _selectedSlotKeysByRequestId
                                    .putIfAbsent(requestId, () => <int>{});
                                if (set.contains(key)) {
                                  set.remove(key);
                                } else {
                                  if (set.length < requiredSelectionCount) {
                                    set.add(key);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          requiredSelectionCount == 1
                                              ? 'You can only select 1 time.'
                                              : 'You can only select 3 times.',
                                          style: GoogleFonts.plusJakartaSans(),
                                        ),
                                        backgroundColor: const Color(
                                          0xFFEF4444,
                                        ),
                                      ),
                                    );
                                  }
                                }
                                if (set.isEmpty) {
                                  _selectedSlotKeysByRequestId.remove(
                                    requestId,
                                  );
                                }
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isBusy
                              ? const Color(0xFFF2F4F7)
                              : (isSelected
                                    ? const Color(0xFF1FBF9A)
                                    : const Color(
                                        0xFF1FBF9A,
                                      ).withOpacity(0.10)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isBusy
                                ? const Color(0xFFE5E7EB)
                                : (isSelected
                                      ? const Color(0xFF1FBF9A)
                                      : const Color(
                                          0xFF1FBF9A,
                                        ).withOpacity(0.25)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: isBusy
                                  ? const Color(0xFF98A2B3)
                                  : (isSelected
                                        ? Colors.white
                                        : const Color(0xFF1FBF9A)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _fmtDateTime(dt),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isBusy
                                    ? const Color(0xFF98A2B3)
                                    : (isSelected
                                          ? Colors.white
                                          : const Color(0xFF1FBF9A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          if (status == 'PENDING') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: proposeSelectedOrSuggested,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isExactRequest
                          ? 'CONFIRM APPOINTMENT'
                          : (selectedKeys.isNotEmpty
                                ? 'PROPOSE SELECTED'
                                : 'CONFIRM SUGGESTED'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _proposeSlots(context, rr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1D2939),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Suggest other',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status != 'PENDING') ...[
            const SizedBox(height: 14),
            Text(
              status == 'CONFIRMED' ? 'Scheduled' : 'Proposed slots',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1D2939),
              ),
            ),
            const SizedBox(height: 10),
            if (slotDts.isEmpty)
              Text(
                '--',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF667085),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: slotDts
                    .map(
                      (dt) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          _fmtDateTime(dt),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF475467),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBody(
    Future<List<Map<String, dynamic>>>? future, {
    required Future<List<Map<String, dynamic>>>? confirmedFuture,
  }) {
    return RefreshIndicator(
      onRefresh: () async => _loadAll(),
      child: FutureBuilder<Map<String, String>>(
        future: _patientNameById,
        builder: (context, patientSnap) {
          final patientNames = patientSnap.data ?? const <String, String>{};
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: confirmedFuture,
            builder: (context, confirmedSnap) {
              final confirmed =
                  confirmedSnap.data ?? const <Map<String, dynamic>>[];
              final busyKeys = _busySlotKeys(confirmed);
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting ||
                      patientSnap.connectionState == ConnectionState.waiting ||
                      confirmedSnap.connectionState ==
                          ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Failed to load: ${snapshot.error}',
                          style: GoogleFonts.plusJakartaSans(),
                        ),
                      ],
                    );
                  }

                  final list = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (list.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'No reservation requests',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildReservationCard(
                        context,
                        list[index],
                        patientNames: patientNames,
                        busyKeys: busyKeys,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2939)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reservations',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1D2939),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          indicatorColor: const Color(0xFF1FBF9A),
          labelColor: const Color(0xFF1FBF9A),
          unselectedLabelColor: const Color(0xFF667085),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Proposed'),
            Tab(text: 'Confirmed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabBody(_pending, confirmedFuture: _confirmed),
          _buildTabBody(_proposed, confirmedFuture: _confirmed),
          _buildTabBody(_confirmed, confirmedFuture: _confirmed),
        ],
      ),
    );
  }
}
