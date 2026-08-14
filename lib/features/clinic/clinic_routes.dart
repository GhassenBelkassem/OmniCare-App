import 'package:flutter/material.dart';

import 'screens/clinic_access_unavailable_screen.dart';
import 'screens/clinic_entry_screen.dart';
import 'screens/clinic_professional_home_screen.dart';
import 'screens/clinic_selection_screen.dart';
import 'screens/clinic_web_workspace_screen.dart';
import 'screens/clinic_operational_list_screens.dart';
import 'screens/clinic_task_detail_screen.dart';

/// Named clinic routes registered in the existing `MaterialApp` route table.
class ClinicRoutes {
  const ClinicRoutes._();

  /// Entry shell: resolves access family, memberships, selection and bootstrap.
  static const String entry = '/clinic';
  static const String selection = '/clinic/select';
  static const String home = '/clinic/home';
  static const String webWorkspace = '/clinic/web-workspace';
  static const String accessUnavailable = '/clinic/access-unavailable';
  static const String positionQueue = '/clinic/queue';
  static const String myTasks = '/clinic/tasks';
  static const String taskDetail = '/clinic/tasks/detail';
  static const String incomingHandovers = '/clinic/handovers';

  static Map<String, WidgetBuilder> builders() {
    return <String, WidgetBuilder>{
      entry: (_) => const ClinicEntryScreen(),
      selection: (_) => const ClinicSelectionScreen(),
      home: (_) => const ClinicProfessionalHomeScreen(),
      webWorkspace: (_) => const ClinicWebWorkspaceScreen(),
      accessUnavailable: (_) => const ClinicAccessUnavailableScreen(),
      positionQueue: (_) => const ClinicOperationalListScreen(
        kind: ClinicOperationalListKind.positionQueue,
      ),
      myTasks: (_) => const ClinicOperationalListScreen(
        kind: ClinicOperationalListKind.myTasks,
      ),
      taskDetail: (_) => const ClinicTaskDetailScreen(),
      incomingHandovers: (_) => const ClinicOperationalListScreen(
        kind: ClinicOperationalListKind.handovers,
      ),
    };
  }
}
