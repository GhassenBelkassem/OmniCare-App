import 'package:flutter/material.dart';

import 'screens/clinic_access_unavailable_screen.dart';
import 'screens/clinic_entry_screen.dart';
import 'screens/clinic_professional_home_screen.dart';
import 'screens/clinic_selection_screen.dart';
import 'screens/clinic_web_workspace_screen.dart';

/// Named clinic routes registered in the existing `MaterialApp` route table.
class ClinicRoutes {
  const ClinicRoutes._();

  /// Entry shell: resolves access family, memberships, selection and bootstrap.
  static const String entry = '/clinic';
  static const String selection = '/clinic/select';
  static const String home = '/clinic/home';
  static const String webWorkspace = '/clinic/web-workspace';
  static const String accessUnavailable = '/clinic/access-unavailable';

  static Map<String, WidgetBuilder> builders() {
    return <String, WidgetBuilder>{
      entry: (_) => const ClinicEntryScreen(),
      selection: (_) => const ClinicSelectionScreen(),
      home: (_) => const ClinicProfessionalHomeScreen(),
      webWorkspace: (_) => const ClinicWebWorkspaceScreen(),
      accessUnavailable: (_) => const ClinicAccessUnavailableScreen(),
    };
  }
}
