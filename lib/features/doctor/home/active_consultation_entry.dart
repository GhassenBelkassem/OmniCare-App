import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/app_http_client.dart';
import '../../scheduled_care/realtime/scheduled_care_event.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import '../consultation_detail_screen.dart';

class ActiveConsultationEntry extends StatefulWidget {
  const ActiveConsultationEntry({super.key});

  @override
  State<ActiveConsultationEntry> createState() =>
      _ActiveConsultationEntryState();
}

class _ActiveConsultationEntryState extends State<ActiveConsultationEntry> {
  _ActiveConsultation? _consultation;
  bool _loading = false;
  bool _initialized = false;
  _ActiveConsultationRealtimeTarget? _target;
  VoidCallback? _unregister;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final coordinator = context.read<ScheduledCareRealtimeCoordinator?>();
      if (coordinator != null) {
        _target = _ActiveConsultationRealtimeTarget(_load);
        _unregister = coordinator.registerTarget(_target!);
      }
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading || !mounted) return;
    setState(() => _loading = true);
    try {
      final response = await context.read<AppHttpClient>().dio.get<dynamic>(
        '/doctor/consultations/active',
      );
      if (!mounted) return;
      final data = response.data;
      setState(() {
        _consultation = data == null
            ? null
            : _ActiveConsultation.fromJson(
                (data as Map).cast<String, dynamic>(),
              );
      });
    } catch (_) {
      // The scheduled-care home remains usable when this independent projection fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consultation = _consultation;
    if (consultation == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Semantics(
        container: true,
        label: 'Consultation active',
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.medical_services_outlined),
            title: const Text('Consultation en cours'),
            subtitle: Text(
              '${consultation.sourceType} · ${consultation.status} · dossier historique ${consultation.medicalAccessStatus}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ConsultationDetailScreen(
                  consultationId: consultation.consultationId,
                  activeWorkspace: true,
                  onCompleted: (_) => _load(),
                  consultation: const <String, dynamic>{},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _unregister?.call();
    _unregister = null;
    _target?.dispose();
    _target = null;
    super.dispose();
  }
}

class _ActiveConsultationRealtimeTarget implements ScheduledCareRealtimeTarget {
  _ActiveConsultationRealtimeTarget(this._refresh);
  final Future<void> Function() _refresh;
  bool _active = false;

  @override
  String get role => 'DOCTOR';
  @override
  void activate() => _active = true;
  @override
  void deactivate() => _active = false;
  @override
  Future<void> invalidate(ScheduledCareInvalidationEvent event) {
    if (_active &&
        event.resourceType == ScheduledCareResourceType.consultation) {
      return _refresh();
    }
    return Future<void>.value();
  }

  @override
  Future<void> resync() => _active ? _refresh() : Future<void>.value();
  @override
  void dispose() => _active = false;
}

class _ActiveConsultation {
  const _ActiveConsultation({
    required this.consultationId,
    required this.sourceType,
    required this.medicalAccessStatus,
    required this.status,
    required this.version,
  });

  final String consultationId;
  final String sourceType;
  final String medicalAccessStatus;
  final String status;
  final int version;

  factory _ActiveConsultation.fromJson(Map<String, dynamic> json) {
    final id = json['consultationId'];
    final source = json['sourceType'];
    final access = json['medicalAccessStatus'];
    final status = json['status'];
    final version = json['version'];
    if (id is! String ||
        source is! String ||
        access is! String ||
        status is! String ||
        version is! int) {
      throw const FormatException('Invalid active Consultation response.');
    }
    return _ActiveConsultation(
      consultationId: id,
      sourceType: source,
      medicalAccessStatus: access,
      status: status,
      version: version,
    );
  }
}
