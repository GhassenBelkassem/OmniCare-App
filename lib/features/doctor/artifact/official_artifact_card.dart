import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/app_http_client.dart';
import '../../scheduled_care/realtime/scheduled_care_event.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import '../clinical_order/clinical_order.dart';
import '../clinical_order/clinical_order_api.dart';
import '../prescription/prescription_api.dart';
import 'artifact.dart';
import 'artifact_api.dart';

class OfficialArtifactCard extends StatefulWidget {
  const OfficialArtifactCard({
    super.key,
    required this.consultationId,
    this.isActive,
  });
  final String consultationId;
  final bool Function()? isActive;
  @override
  State<OfficialArtifactCard> createState() => _OfficialArtifactCardState();
}

class _OfficialArtifactCardState extends State<OfficialArtifactCard> {
  late ArtifactApi _api;
  List<OfficialArtifact> _items = const [];
  bool _loading = true, _busy = false, _dirty = false, _newer = false;
  String? _error, _editingId, _type;
  final ArtifactMutationKeys _mutationKeys = ArtifactMutationKeys();
  final _statement = TextEditingController(),
      _start = TextEditingController(),
      _end = TextEditingController(),
      _days = TextEditingController(text: '1');
  VoidCallback? _unregister;
  _ArtifactRealtimeTarget? _target;
  bool get _isActive => widget.isActive?.call() ?? true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isActive || !_loading || _unregister != null) return;
    final http = context.read<AppHttpClient>();
    _api = ArtifactApi(http);
    final coordinator = context.read<ScheduledCareRealtimeCoordinator?>();
    if (coordinator != null) {
      _target = _ArtifactRealtimeTarget(
        this,
        isWorkspaceActive: widget.isActive,
      );
      _unregister = coordinator.registerTarget(_target!);
    }
    _load();
  }

  @override
  void dispose() {
    _target?.dispose();
    _unregister?.call();
    _statement.dispose();
    _start.dispose();
    _end.dispose();
    _days.dispose();
    _mutationKeys.clear();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (!_isActive) return;
    if (_dirty && !force) {
      setState(() => _newer = true);
      return;
    }
    try {
      final values = await _api.listDoctor(widget.consultationId);
      if (mounted) {
        setState(() {
          _items = values;
          _loading = false;
          _newer = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _code(e);
        });
      }
    }
  }

  void _begin(String type) {
    setState(() {
      _type = type;
      _editingId = 'new';
      _statement.clear();
      _start.clear();
      _end.clear();
      _days.text = '1';
      _dirty = false;
    });
  }

  void _edit(OfficialArtifact value) {
    final raw = value.definition['certificate'];
    final certificate = raw is Map
        ? raw.cast<String, dynamic>()
        : const <String, dynamic>{};
    setState(() {
      _type = value.type;
      _editingId = value.id;
      _statement.text = certificate['statement'] as String? ?? '';
      _start.text = certificate['startDate'] as String? ?? '';
      _end.text = certificate['endDate'] as String? ?? '';
      _days.text =
          (certificate['durationDays'] as num?)?.toInt().toString() ?? '1';
      _dirty = false;
    });
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Map<String, dynamic> _definition() => {
    'statement': _statement.text.trim(),
    if (_type == 'SICK_LEAVE_CERTIFICATE') ...{
      'startDate': _start.text,
      'endDate': _end.text,
      'durationDays': int.tryParse(_days.text) ?? 0,
    },
  };
  Future<void> _save() async {
    if (_type == null || _busy) return;
    final definition = _definition();
    final operation =
        'save:${jsonEncode({'id': _editingId, 'type': _type, 'definition': definition, if (_editingId != 'new') 'version': _items.firstWhere((e) => e.id == _editingId).version})}';
    final idempotencyKey = _mutationKeys.acquire(operation);
    setState(() => _busy = true);
    try {
      OfficialArtifact saved;
      if (_editingId == 'new') {
        saved = await _api.createCertificate(
          widget.consultationId,
          _type!,
          definition,
          idempotencyKey,
        );
      } else {
        saved = await _api.update(
          widget.consultationId,
          _items.firstWhere((e) => e.id == _editingId),
          definition,
          idempotencyKey,
        );
      }
      if (mounted) {
        setState(() {
          _items = [..._items.where((e) => e.id != saved.id), saved];
          _editingId = saved.id;
          _dirty = false;
          _error = null;
          _mutationKeys.complete(operation);
        });
      }
    } catch (e) {
      if (!_ambiguous(e)) _mutationKeys.complete(operation);
      if (mounted) setState(() => _error = _code(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize(OfficialArtifact value) async {
    if (_busy || (_editingId == value.id && _dirty)) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Finalize and sign?'),
            content: const Text(
              'The official definition becomes immutable. This does not finish the Consultation.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Finalize'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _busy = true);
    final operation = 'finalize:${value.id}:${value.version}';
    try {
      final key = _mutationKeys.acquire(operation);
      final saved = await _api.finalize(widget.consultationId, value, key);
      _mutationKeys.complete(operation);
      if (mounted) {
        setState(
          () => _items = [..._items.where((e) => e.id != saved.id), saved],
        );
      }
    } catch (e) {
      if (!_ambiguous(e)) _mutationKeys.complete(operation);
      if (mounted) setState(() => _error = _code(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sources() async {
    if (_busy || !_isActive) return;
    setState(() => _busy = true);
    try {
      final http = context.read<AppHttpClient>();
      final prescription = await PrescriptionApi(
        http,
      ).read(widget.consultationId);
      if (prescription.finalized &&
          prescription.prescriptionId != null &&
          !_items.any((e) => e.sourceId == prescription.prescriptionId)) {
        final operation =
            'source:PRESCRIPTION:${prescription.prescriptionId}:${prescription.prescriptionVersion}';
        final created = await _api.createSource(
          widget.consultationId,
          'PRESCRIPTION',
          prescription.prescriptionId!,
          prescription.prescriptionVersion,
          _mutationKeys.acquire(operation),
        );
        _mutationKeys.complete(operation);
        _items = [..._items, created];
      }
      final orders = await ClinicalOrderApi(http).list(widget.consultationId);
      for (final order in orders.where(
        (e) =>
            e.status == ClinicalOrderStatus.finalized &&
            e.category != ClinicalOrderCategory.referral &&
            !_items.any((a) => a.sourceId == e.id),
      )) {
        final operation =
            'source:${order.category.name}:${order.id}:${order.version}';
        final created = await _api.createSource(
          widget.consultationId,
          order.category == ClinicalOrderCategory.lab
              ? 'LAB_ORDER'
              : 'IMAGING_ORDER',
          order.id,
          order.version,
          _mutationKeys.acquire(operation),
        );
        _mutationKeys.complete(operation);
        _items = [..._items, created];
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = _code(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(OfficialArtifact value) async {
    try {
      final bytes = await _api.downloadDoctor(widget.consultationId, value.id);
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save official PDF',
        fileName: '${value.type.toLowerCase()}.pdf',
        bytes: bytes,
      );
    } catch (e) {
      if (mounted) setState(() => _error = _code(e));
    }
  }

  void _clearVolatile() {
    _mutationKeys.clear();
    _statement.clear();
    _start.clear();
    _end.clear();
    _days.text = '1';
    if (mounted) {
      setState(() {
        _items = const [];
        _editingId = null;
        _type = null;
        _dirty = false;
        _newer = false;
        _error = null;
        _loading = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _Surface(child: Center(child: CircularProgressIndicator()));
    }
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Official artifacts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Text(
            'MRS definitions; PDFs render only after Consultation completion.',
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _begin('MEDICAL_CERTIFICATE'),
                child: const Text('Medical certificate'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _begin('SICK_LEAVE_CERTIFICATE'),
                child: const Text('Sick leave'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _sources,
                child: const Text('Add finalized prescription/orders'),
              ),
            ],
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
          if (_newer)
            const Text(
              'A newer server version exists; the local draft is preserved.',
            ),
          if (_editingId != null) ...[
            TextField(
              controller: _statement,
              onChanged: (_) => _changed(),
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Non-diagnostic statement',
              ),
            ),
            if (_type == 'SICK_LEAVE_CERTIFICATE') ...[
              TextField(
                controller: _start,
                onChanged: (_) => _changed(),
                decoration: const InputDecoration(
                  labelText: 'Start (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: _end,
                onChanged: (_) => _changed(),
                decoration: const InputDecoration(
                  labelText: 'End (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: _days,
                onChanged: (_) => _changed(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration days'),
              ),
            ],
            const Text('Diagnosis is excluded. No statutory compliance claim.'),
            FilledButton(
              onPressed: _dirty && !_busy ? _save : null,
              child: const Text('Save draft'),
            ),
          ],
          ..._items.map(
            (value) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(value.type.replaceAll('_', ' ')),
              subtitle: Text(
                'v${value.version} · ${value.status} · ${value.renderStatus}',
              ),
              trailing: Wrap(
                children: [
                  if (!value.finalized)
                    IconButton(
                      onPressed:
                          value.type == 'MEDICAL_CERTIFICATE' ||
                              value.type == 'SICK_LEAVE_CERTIFICATE'
                          ? () => _edit(value)
                          : null,
                      tooltip: 'Edit draft',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (!value.finalized)
                    IconButton(
                      onPressed: () => _finalize(value),
                      tooltip: 'Finalize',
                      icon: const Icon(Icons.verified_outlined),
                    ),
                  if (value.ready)
                    IconButton(
                      onPressed: () => _download(value),
                      tooltip: 'Save PDF',
                      icon: const Icon(Icons.download),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class _ArtifactRealtimeTarget implements ScheduledCareRealtimeTarget {
  _ArtifactRealtimeTarget(this.state, {bool Function()? isWorkspaceActive})
    : _isWorkspaceActive = isWorkspaceActive;
  final _OfficialArtifactCardState state;
  final bool Function()? _isWorkspaceActive;
  bool active = false;
  bool get _canRefresh => active && (_isWorkspaceActive?.call() ?? true);
  @override
  String get role => 'DOCTOR';
  @override
  void activate() => active = true;
  @override
  void deactivate() {
    if (!active) return;
    active = false;
    state._clearVolatile();
  }

  @override
  Future<void> invalidate(ScheduledCareInvalidationEvent event) =>
      _canRefresh && event.resourceType == ScheduledCareResourceType.artifact
      ? state._load()
      : Future.value();
  @override
  Future<void> resync() => _canRefresh ? state._load() : Future.value();
  @override
  void dispose() => active = false;
}

String _code(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final code =
          data['errorCode'] ??
          (data['error'] is Map ? (data['error'] as Map)['code'] : null);
      if (code == 'ARTIFACT_VERSION_CONFLICT') {
        return 'ARTIFACT_VERSION_CONFLICT — local draft preserved.';
      }
      if (code is String) return code;
    }
  }
  return error.toString().contains('ARTIFACT_VERSION_CONFLICT')
      ? 'ARTIFACT_VERSION_CONFLICT — local draft preserved.'
      : 'Artifact operation temporarily unavailable.';
}

bool _ambiguous(Object error) =>
    error is DioException &&
    (error.response == null || (error.response?.statusCode ?? 0) >= 500);
