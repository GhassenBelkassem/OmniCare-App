import 'package:flutter/material.dart';

import 'core/maps/synthetic_maps_smoke_screen.dart';

void main() => runApp(const _MapsSmokeApp());

class _MapsSmokeApp extends StatelessWidget {
  const _MapsSmokeApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'OmniCare Maps Smoke Test',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff245d63)),
      useMaterial3: true,
    ),
    home: const SyntheticMapsSmokeScreen(),
  );
}
