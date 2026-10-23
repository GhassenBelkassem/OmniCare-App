import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../request_core/application/request_submission_controller.dart';
import 'who_needs_care_screen.dart';

/// True entry point of the Module 05 clinic-request flow.
///
/// Starts exactly one fresh logical request (new operation id, cleared
/// in-flight record) and shows the first step. It is only reached from a
/// deliberate "request care" action; the in-flow "Change" actions navigate to
/// [WhoNeedsCareScreen] directly and therefore keep the existing operation id.
class RequestFlowEntryScreen extends StatefulWidget {
  const RequestFlowEntryScreen({super.key});

  @override
  State<RequestFlowEntryScreen> createState() => _RequestFlowEntryScreenState();
}

class _RequestFlowEntryScreenState extends State<RequestFlowEntryScreen> {
  @override
  void initState() {
    super.initState();
    // The controller notifies synchronously, so begin only after the first
    // frame instead of notifying Provider dependants while this route builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RequestSubmissionController>().beginNewRequest();
    });
  }

  @override
  Widget build(BuildContext context) => const WhoNeedsCareScreen();
}
