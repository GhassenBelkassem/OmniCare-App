import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_doctor/application/doctor_directory_controller.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_failure.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_repository.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_directory_screen.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/widgets/doctor_filter_sheet.dart';

Widget _app(_ScreenRepository repository) {
  return ChangeNotifierProvider(
    create: (_) => DoctorDirectoryController(repository: repository),
    child: MaterialApp(
      theme: buildOmniTheme(),
      home: const DoctorDirectoryScreen(),
    ),
  );
}

Widget _appWithController(DoctorDirectoryController controller) {
  return ChangeNotifierProvider.value(
    value: controller,
    child: MaterialApp(
      theme: buildOmniTheme(),
      home: const DoctorDirectoryScreen(),
    ),
  );
}

void main() {
  testWidgets('shows a distinct initial loading state', (tester) async {
    final firstPage = Completer<DoctorSearchPage>();
    final controller = DoctorDirectoryController(
      repository: _ScreenRepository(onSearch: (_) => firstPage.future),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_appWithController(controller));
    await tester.pump();

    expect(controller.status, DoctorDirectoryStatus.loadingFirst);

    firstPage.complete(
      const DoctorSearchPage(content: [], page: 0, size: 20, hasNext: false),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('shows the real empty state without demo Doctors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _ScreenRepository(
          onSearch: (_) async => const DoctorSearchPage(
            content: [],
            page: 0,
            size: 20,
            hasNext: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun médecin disponible'), findsOneWidget);
    expect(find.byKey(const ValueKey('doctor-card-demo')), findsNothing);
  });

  testWidgets('maps initial failures to a safe retry UI', (tester) async {
    var fail = true;
    final repository = _ScreenRepository(
      onSearch: (_) async {
        if (fail) throw DoctorDirectoryFailure.networkUnavailable;
        return const DoctorSearchPage(
          content: [],
          page: 0,
          size: 20,
          hasNext: false,
        );
      },
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('Connection unavailable'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun médecin disponible'), findsOneWidget);
  });

  testWidgets('filter sheet exposes only certified backend filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _ScreenRepository(
          onSearch: (_) async => const DoctorSearchPage(
            content: [],
            page: 0,
            size: 20,
            hasNext: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(DoctorFilterSheet), findsOneWidget);
    expect(find.text('Spécialité'), findsOneWidget);
    expect(find.text('Localisation du cabinet'), findsOneWidget);
    expect(find.text('Distance autour de moi'), findsOneWidget);
    expect(find.text('Type de prise en charge'), findsOneWidget);
    expect(find.text('CNAM accepté'), findsOneWidget);
    expect(find.text('Assurance privée acceptée'), findsOneWidget);
    expect(find.text('Accepte de nouveaux patients'), findsOneWidget);
    expect(find.textContaining('Prix'), findsNothing);
    expect(find.textContaining('Mieux notés'), findsNothing);
    expect(find.textContaining('Disponible le samedi'), findsNothing);
  });
}

class _ScreenRepository implements DoctorDirectoryRepository {
  _ScreenRepository({required this.onSearch});

  final Future<DoctorSearchPage> Function(DoctorSearchCriteria) onSearch;

  @override
  Future<DoctorSearchPage> searchDoctors({
    required DoctorSearchCriteria criteria,
    CancelToken? cancelToken,
  }) => onSearch(criteria);

  @override
  Future<DoctorDirectoryDetail> getDoctor(
    String doctorId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<List<AvailabilitySlotDto>> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}
