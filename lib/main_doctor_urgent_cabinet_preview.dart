import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/theme/omni_theme.dart';
import 'features/doctor/urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import 'features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision_source.dart';
import 'features/doctor/urgent_cabinet/doctor_urgent_cabinet_request.dart';
import 'features/doctor/urgent_cabinet/doctor_urgent_cabinet_request_source.dart';
import 'features/doctor/urgent_cabinet/doctor_urgent_cabinet_screen.dart';
import 'features/doctor/workspace/doctor_workspace_config.dart';

const _doctorId = String.fromEnvironment(
  'D_UI_02_DOCTOR_ID',
  defaultValue: 'doctor-d-ui-02-preview',
);
const _cabinetName = String.fromEnvironment(
  'D_UI_02_CABINET_NAME',
  defaultValue: 'Cabinet La Marsa Démo',
);
const _cabinetAddress = String.fromEnvironment(
  'D_UI_02_CABINET_ADDRESS',
  defaultValue: '1, rue de la Santé',
);
const _cabinetCity = String.fromEnvironment(
  'D_UI_02_CABINET_CITY',
  defaultValue: 'La Marsa',
);
const _cabinetGovernorate = String.fromEnvironment(
  'D_UI_02_CABINET_GOVERNORATE',
  defaultValue: 'Tunis',
);

void main() {
  runApp(const _DoctorUrgentCabinetPreviewApp());
}

class _DoctorUrgentCabinetPreviewApp extends StatelessWidget {
  const _DoctorUrgentCabinetPreviewApp();

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return MaterialApp(
        theme: buildOmniTheme(),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('The D-UI-02 request preview is debug-only.'),
            ),
          ),
        ),
      );
    }

    const cabinetConfig = DoctorCabinetConfig(
      name: _cabinetName,
      address: _cabinetAddress,
      city: _cabinetCity,
      governorate: _cabinetGovernorate,
    );
    final cabinet = DoctorUrgentCabinetSnapshot(
      name: cabinetConfig.name,
      address: cabinetConfig.address,
      city: cabinetConfig.city,
      governorate: cabinetConfig.governorate,
    );
    final request = DoctorUrgentCabinetRequest(
      developmentFixtureKey: DoctorUrgentCabinetDevelopmentFixtureKey(
        'd-ui-02-preview-request',
      ),
      targetDoctorId: _doctorId,
      targetCabinetIdentity: DoctorUrgentCabinetDevelopmentTargetIdentity(
        DoctorUrgentCabinetDevelopmentCabinetKey('d-ui-02-preview-cabinet'),
      ),
      cabinet: cabinet,
      patient: const DoctorUrgentCabinetPatientProjection.masked(),
      fee: DoctorUrgentCabinetFeeSnapshot(
        amountMilliTnd: 75000,
        currencyCode: 'TND',
        provenance: DoctorUrgentCabinetFeeProvenance.developmentFixture,
      ),
      dataProvenance: DoctorUrgentCabinetDataProvenance.developmentFixture,
      status: DoctorUrgentCabinetRequestStatus.newRequest,
    );
    final workspace = DoctorWorkspaceConfig(
      doctorId: _doctorId,
      onboardingCompleted: true,
      practiceModes: const {DoctorPracticeMode.cabinet},
      services: const {
        DoctorWorkspaceService.cabinetConsultations,
        DoctorWorkspaceService.urgentCabinetConsultations,
      },
      cabinet: cabinetConfig,
      clinics: const [],
      availability: const DoctorAvailability(
        workingDays: {DoctorWorkingDay.monday},
        startTime: '08:00',
        endTime: '17:00',
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildOmniTheme(),
      home: Scaffold(
        backgroundColor: OmniColors.pageBackground,
        body: SafeArea(
          child: _DoctorUrgentCabinetPreviewBody(
            workspace: workspace,
            request: request,
          ),
        ),
      ),
    );
  }
}

class _DoctorUrgentCabinetPreviewBody extends StatefulWidget {
  const _DoctorUrgentCabinetPreviewBody({
    required this.workspace,
    required this.request,
  });

  final DoctorWorkspaceConfig workspace;
  final DoctorUrgentCabinetRequest request;

  @override
  State<_DoctorUrgentCabinetPreviewBody> createState() =>
      _DoctorUrgentCabinetPreviewBodyState();
}

class _DoctorUrgentCabinetPreviewBodyState
    extends State<_DoctorUrgentCabinetPreviewBody> {
  late final DoctorUrgentCabinetController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DoctorUrgentCabinetController()
      ..configure(
        authenticatedDoctorId: widget.workspace.doctorId,
        workspaceConfig: widget.workspace,
        requestSource: DoctorUrgentCabinetDevelopmentRequestSource(
          requests: [widget.request],
        ),
        decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
          request: widget.request,
        ),
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DoctorUrgentCabinetScreen(
    workspaceConfig: widget.workspace,
    controller: _controller,
  );
}
