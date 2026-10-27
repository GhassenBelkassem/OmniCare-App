import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/app_http_client.dart';
import '../../doctor/artifact/artifact.dart';
import '../../doctor/artifact/artifact_api.dart';
import '../../scheduled_care/realtime/scheduled_care_event.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';

class PatientArtifactCard extends StatefulWidget {
  const PatientArtifactCard({
    super.key,
    required this.consultationId,
    required this.subjectType,
    this.familyMemberId,
  });
  final String consultationId, subjectType;
  final String? familyMemberId;
  @override
  State<PatientArtifactCard> createState() => _PatientArtifactCardState();
}

class _PatientArtifactCardState extends State<PatientArtifactCard> {
  List<OfficialArtifact> _items = const [];
  bool _loading = true;
  String? _error;
  late ArtifactApi _api;
  VoidCallback? _unregister;
  _PatientArtifactRealtimeTarget? _target;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading) return;
    _api = ArtifactApi(context.read<AppHttpClient>());
    final coordinator = context.read<ScheduledCareRealtimeCoordinator?>();
    if (coordinator != null && _unregister == null) {
      _target = _PatientArtifactRealtimeTarget(this);
      _unregister = coordinator.registerTarget(_target!);
    }
    _load();
  }

  @override
  void dispose() {
    _unregister?.call();
    _target?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await _api.listPatient(
        widget.consultationId,
        widget.subjectType,
        widget.familyMemberId,
      );
      if (mounted) {
        setState(() {
          _items = values;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Official artifacts are temporarily unavailable.';
        });
      }
    }
  }

  Future<void> _save(OfficialArtifact value) async {
    try {
      final bytes = await _api.downloadPatient(
        widget.consultationId,
        value.id,
        widget.subjectType,
        widget.familyMemberId,
      );
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save official PDF',
        fileName: '${value.type.toLowerCase()}.pdf',
        bytes: bytes,
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'The PDF could not be downloaded.');
    }
  }

  void _clearVolatile() {
    if (!mounted) return;
    setState(() {
      _items = const [];
      _loading = true;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Official documents',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
        if (!_loading && _items.isEmpty)
          const Text('No finalized official document for this Consultation.'),
        ..._items.map(
          (value) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(value.type.replaceAll('_', ' ')),
            subtitle: Text(
              value.ready
                  ? 'Ready'
                  : value.renderStatus.replaceAll('_', ' ').toLowerCase(),
            ),
            trailing: value.ready
                ? IconButton(
                    onPressed: () => _save(value),
                    tooltip: 'Save PDF',
                    icon: const Icon(Icons.download),
                  )
                : null,
          ),
        ),
      ],
    ),
  );
}

class _PatientArtifactRealtimeTarget implements ScheduledCareRealtimeTarget {
  _PatientArtifactRealtimeTarget(this.state);
  final _PatientArtifactCardState state;
  bool active = false;

  @override
  String get role => 'PATIENT';
  @override
  void activate() => active = true;
  @override
  void deactivate() {
    active = false;
    state._clearVolatile();
  }

  @override
  Future<void> invalidate(ScheduledCareInvalidationEvent event) =>
      active && event.resourceType == ScheduledCareResourceType.artifact
      ? state._load()
      : Future.value();
  @override
  Future<void> resync() => active ? state._load() : Future.value();
  @override
  void dispose() => active = false;
}
