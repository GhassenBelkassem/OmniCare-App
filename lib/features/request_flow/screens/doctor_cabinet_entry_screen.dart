import 'package:flutter/material.dart';
import '../../request_core/domain/request_vocabulary.dart';
import 'who_needs_care_screen.dart';

/// Entry point of the Doctor Cabinet request flow.
///
/// Starts a fresh logical request and shows the shared [WhoNeedsCareScreen]
/// with [RequestKind.doctor], so the Continue action navigates to the
/// [DoctorDirectoryScreen] instead of the [ClinicDirectoryScreen].
///
/// This mirrors [RequestFlowEntryScreen] but is scoped to the doctor cabinet
/// consultation path. It does NOT submit to any backend — [RequestKind.doctor]
/// is navigation-only at this stage.
class DoctorCabinetEntryScreen extends StatelessWidget {
  const DoctorCabinetEntryScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const WhoNeedsCareScreen(requestKind: RequestKind.doctor);
}
