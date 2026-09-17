import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/omni_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA - French labels
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> muscleParts = {
  'front-head': 'Tête',
  'front-neck': 'Cou',
  'back-neck': 'Nuque',
  'front-chest-pectoral-left': 'Pectoraux Gauche',
  'front-chest-pectoral-right': 'Pectoraux Droit',
  'front-abs-upper': 'Abdomen Supérieur',
  'front-abs-middle': 'Abdomen Moyen',
  'front-abs-lower': 'Abdomen Inférieur',
  'front-oblique-left': 'Obliques Gauche',
  'front-oblique-right': 'Obliques Droit',
  'front-serratus-left': 'Serratus Gauche',
  'front-serratus-right': 'Serratus Droit',
  'back-trap-upper': 'Trapèze Supérieur',
  'back-lat-left': 'Dorsaux Gauche',
  'back-lat-right': 'Dorsaux Droit',
  'back-spine-upper': 'Colonne Supérieure',
  'back-spine-middle': 'Colonne Moyenne',
  'back-lumbar': 'Bas du Dos',
  'back-glute-left': 'Fessier Gauche',
  'back-glute-right': 'Fessier Droit',
  'front-shoulder-deltoid-left': 'Épaule Gauche',
  'front-shoulder-deltoid-right': 'Épaule Droite',
  'back-shoulder-deltoid-left': 'Épaule Arrière Gauche',
  'back-shoulder-deltoid-right': 'Épaule Arrière Droite',
  'front-bicep-left': 'Biceps Gauche',
  'front-bicep-right': 'Biceps Droit',
  'back-tricep-left': 'Triceps Gauche',
  'back-tricep-right': 'Triceps Droit',
  'front-forearm-left': 'Avant-bras Gauche',
  'front-forearm-right': 'Avant-bras Droit',
  'back-forearm-left': 'Avant-bras Gauche',
  'back-forearm-right': 'Avant-bras Droit',
  'front-hand-left': 'Main Gauche',
  'front-hand-right': 'Main Droite',
  'back-hand-left': 'Main Gauche',
  'back-hand-right': 'Main Droite',
  'front-thigh-quad-left': 'Quadriceps Gauche',
  'front-thigh-quad-right': 'Quadriceps Droit',
  'back-thigh-hamstring-left': 'Ischio-jambiers Gauche',
  'back-thigh-hamstring-right': 'Ischio-jambiers Droit',
  'front-knee-left': 'Genou Gauche',
  'front-knee-right': 'Genou Droit',
  'back-knee-left': 'Genou Arrière Gauche',
  'back-knee-right': 'Genou Arrière Droit',
  'front-shin-left': 'Tibia Gauche',
  'front-shin-right': 'Tibia Droit',
  'front-calf-left': 'Mollet Gauche',
  'front-calf-right': 'Mollet Droit',
  'back-calf-left': 'Mollet Gauche',
  'back-calf-right': 'Mollet Droit',
  'front-foot-left': 'Pied Gauche',
  'front-foot-right': 'Pied Droit',
  'back-foot-left': 'Pied Gauche',
  'back-foot-right': 'Pied Droit',
};

/// Patient-facing copy only. Stable anatomical IDs remain unchanged.
String bodyAreaLabel(String id) {
  const overrides = {
    'front-chest-pectoral-left': 'Poitrine gauche',
    'front-chest-pectoral-right': 'Poitrine droite',
    'front-serratus-left': 'Côtes gauches',
    'front-serratus-right': 'Côtes droites',
    'front-thigh-quad-left': 'Cuisse gauche (face)',
    'front-thigh-quad-right': 'Cuisse droite (face)',
    'back-thigh-hamstring-left': 'Cuisse gauche (dos)',
    'back-thigh-hamstring-right': 'Cuisse droite (dos)',
  };
  if (overrides.containsKey(id)) return overrides[id]!;
  final label = muscleParts[id];
  if (label == null) return 'Zone sélectionnée';
  final duplicate =
      muscleParts.values.where((value) => value == label).length > 1;
  return duplicate
      ? '$label (${id.startsWith('back-') ? 'dos' : 'face'})'
      : label;
}

// ─────────────────────────────────────────────────────────────────────────────
// TAP ZONE MODEL
// All values are fractions (0.0–1.0) of the rendered widget size.
// Derived directly from SVG viewBox coords: x/300, y/650, w/300, h/650.
// ─────────────────────────────────────────────────────────────────────────────

class _TapZone {
  final String part;
  final double left;
  final double top;
  final double width;
  final double height;
  final String shape; // 'rect' or 'ellipse'

  const _TapZone({
    required this.part,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.shape = 'rect',
  });

  bool contains(double fx, double fy) {
    if (shape == 'ellipse') {
      final cx = left + width / 2;
      final cy = top + height / 2;
      final dx = (fx - cx) / (width / 2);
      final dy = (fy - cy) / (height / 2);
      return dx * dx + dy * dy <= 1.0;
    }
    return fx >= left && fx <= left + width && fy >= top && fy <= top + height;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FRONT TAP ZONES — exact fractions from SVG (viewBox 300×650)
// Order: back-to-front so last defined = highest tap priority
// ─────────────────────────────────────────────────────────────────────────────

const List<_TapZone> _frontZones = [
  // Feet  (ellipse cx=114,cy=592,rx=22,ry=26  &  cx=186)
  _TapZone(
    part: 'front-foot-left',
    shape: 'ellipse',
    left: 0.3067,
    top: 0.8708,
    width: 0.1467,
    height: 0.0800,
  ),
  _TapZone(
    part: 'front-foot-right',
    shape: 'ellipse',
    left: 0.5467,
    top: 0.8708,
    width: 0.1467,
    height: 0.0800,
  ),
  // Calves  (ellipse cx=104,cy=516,rx=9,ry=44  &  cx=196)
  _TapZone(
    part: 'front-calf-left',
    shape: 'ellipse',
    left: 0.3167,
    top: 0.7262,
    width: 0.0600,
    height: 0.1354,
  ),
  _TapZone(
    part: 'front-calf-right',
    shape: 'ellipse',
    left: 0.6233,
    top: 0.7262,
    width: 0.0600,
    height: 0.1354,
  ),
  // Shins  (rect x=110,y=464,w=16,h=100  &  x=174)
  _TapZone(
    part: 'front-shin-left',
    left: 0.3667,
    top: 0.7138,
    width: 0.0533,
    height: 0.1538,
  ),
  _TapZone(
    part: 'front-shin-right',
    left: 0.5800,
    top: 0.7138,
    width: 0.0533,
    height: 0.1538,
  ),
  // Knees  (ellipse cx=120,cy=442,rx=17,ry=20  &  cx=180)
  _TapZone(
    part: 'front-knee-left',
    shape: 'ellipse',
    left: 0.3433,
    top: 0.6492,
    width: 0.1133,
    height: 0.0615,
  ),
  _TapZone(
    part: 'front-knee-right',
    shape: 'ellipse',
    left: 0.5433,
    top: 0.6492,
    width: 0.1133,
    height: 0.0615,
  ),
  // Quads  (path bbox x=108,y=272,w=30,h=158  &  x=162)
  _TapZone(
    part: 'front-thigh-quad-left',
    left: 0.3600,
    top: 0.4185,
    width: 0.1000,
    height: 0.2431,
  ),
  _TapZone(
    part: 'front-thigh-quad-right',
    left: 0.5400,
    top: 0.4185,
    width: 0.1000,
    height: 0.2431,
  ),
  // Hands  (ellipse cx=83,cy=312,rx=12,ry=17  &  cx=217)
  _TapZone(
    part: 'front-hand-left',
    shape: 'ellipse',
    left: 0.2367,
    top: 0.4538,
    width: 0.0800,
    height: 0.0523,
  ),
  _TapZone(
    part: 'front-hand-right',
    shape: 'ellipse',
    left: 0.6833,
    top: 0.4538,
    width: 0.0800,
    height: 0.0523,
  ),
  // Forearms  (path bbox x=75,y=224,w=19,h=72  &  x=206)
  _TapZone(
    part: 'front-forearm-left',
    left: 0.2500,
    top: 0.3446,
    width: 0.0633,
    height: 0.1108,
  ),
  _TapZone(
    part: 'front-forearm-right',
    left: 0.6867,
    top: 0.3446,
    width: 0.0633,
    height: 0.1108,
  ),
  // Obliques  (path bbox x=104,y=188,w=20,h=78  &  x=176)
  _TapZone(
    part: 'front-oblique-left',
    left: 0.3467,
    top: 0.2892,
    width: 0.0667,
    height: 0.1200,
  ),
  _TapZone(
    part: 'front-oblique-right',
    left: 0.5867,
    top: 0.2892,
    width: 0.0667,
    height: 0.1200,
  ),
  // Abs lower  (rect x=131,y=232,w=38,h=26)
  _TapZone(
    part: 'front-abs-lower',
    left: 0.4367,
    top: 0.3569,
    width: 0.1267,
    height: 0.0400,
  ),
  // Abs middle  (rect x=129,y=200,w=42,h=28)
  _TapZone(
    part: 'front-abs-middle',
    left: 0.4300,
    top: 0.3077,
    width: 0.1400,
    height: 0.0431,
  ),
  // Abs upper  (rect x=127,y=168,w=46,h=28)
  _TapZone(
    part: 'front-abs-upper',
    left: 0.4233,
    top: 0.2585,
    width: 0.1533,
    height: 0.0431,
  ),
  // Serratus  (path bbox x=102,y=148,w=14,h=40  &  x=184)
  _TapZone(
    part: 'front-serratus-left',
    left: 0.3400,
    top: 0.2277,
    width: 0.0467,
    height: 0.0615,
  ),
  _TapZone(
    part: 'front-serratus-right',
    left: 0.6133,
    top: 0.2277,
    width: 0.0467,
    height: 0.0615,
  ),
  // Biceps  (ellipse cx=87,cy=190,rx=12,ry=32  &  cx=213)
  _TapZone(
    part: 'front-bicep-left',
    shape: 'ellipse',
    left: 0.2500,
    top: 0.2431,
    width: 0.0800,
    height: 0.0985,
  ),
  _TapZone(
    part: 'front-bicep-right',
    shape: 'ellipse',
    left: 0.6700,
    top: 0.2431,
    width: 0.0800,
    height: 0.0985,
  ),
  // Pectorals  (path bbox x=100,y=108,w=48,h=57  &  x=152)
  _TapZone(
    part: 'front-chest-pectoral-left',
    left: 0.3333,
    top: 0.1662,
    width: 0.1600,
    height: 0.0877,
  ),
  _TapZone(
    part: 'front-chest-pectoral-right',
    left: 0.5067,
    top: 0.1662,
    width: 0.1600,
    height: 0.0877,
  ),
  // Deltoids  (path bbox x=72,y=108,w=38,h=54  &  x=190)
  _TapZone(
    part: 'front-shoulder-deltoid-left',
    left: 0.2400,
    top: 0.1662,
    width: 0.1267,
    height: 0.0831,
  ),
  _TapZone(
    part: 'front-shoulder-deltoid-right',
    left: 0.6333,
    top: 0.1662,
    width: 0.1267,
    height: 0.0831,
  ),
  // Neck  (rect x=137,y=79,w=26,h=26)
  _TapZone(
    part: 'front-neck',
    left: 0.4567,
    top: 0.1215,
    width: 0.0867,
    height: 0.0400,
  ),
  // Head  (ellipse cx=150,cy=45,rx=32,ry=38) — highest priority, defined last
  _TapZone(
    part: 'front-head',
    shape: 'ellipse',
    left: 0.3933,
    top: 0.0108,
    width: 0.2133,
    height: 0.1169,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// BACK TAP ZONES — exact fractions from SVG (viewBox 300×650)
// ─────────────────────────────────────────────────────────────────────────────

const List<_TapZone> _backZones = [
  // Feet  (ellipse cx=116,cy=594,rx=20,ry=25  &  cx=184)
  _TapZone(
    part: 'back-foot-left',
    shape: 'ellipse',
    left: 0.3200,
    top: 0.8754,
    width: 0.1333,
    height: 0.0769,
  ),
  _TapZone(
    part: 'back-foot-right',
    shape: 'ellipse',
    left: 0.5467,
    top: 0.8754,
    width: 0.1333,
    height: 0.0769,
  ),
  // Calves  (ellipse cx=120,cy=520,rx=15,ry=52  &  cx=180)
  _TapZone(
    part: 'back-calf-left',
    shape: 'ellipse',
    left: 0.3500,
    top: 0.7200,
    width: 0.1000,
    height: 0.1600,
  ),
  _TapZone(
    part: 'back-calf-right',
    shape: 'ellipse',
    left: 0.5500,
    top: 0.7200,
    width: 0.1000,
    height: 0.1600,
  ),
  // Knees  (ellipse cx=120,cy=447,rx=17,ry=19  &  cx=180)
  _TapZone(
    part: 'back-knee-left',
    shape: 'ellipse',
    left: 0.3433,
    top: 0.6585,
    width: 0.1133,
    height: 0.0585,
  ),
  _TapZone(
    part: 'back-knee-right',
    shape: 'ellipse',
    left: 0.5433,
    top: 0.6585,
    width: 0.1133,
    height: 0.0585,
  ),
  // Hamstrings  (path bbox x=108,y=358,w=30,h=75  &  x=162)
  _TapZone(
    part: 'back-thigh-hamstring-left',
    left: 0.3600,
    top: 0.5508,
    width: 0.1000,
    height: 0.1154,
  ),
  _TapZone(
    part: 'back-thigh-hamstring-right',
    left: 0.5400,
    top: 0.5508,
    width: 0.1000,
    height: 0.1154,
  ),
  // Hands  (ellipse cx=83,cy=312,rx=12,ry=17  &  cx=217)
  _TapZone(
    part: 'back-hand-left',
    shape: 'ellipse',
    left: 0.2367,
    top: 0.4538,
    width: 0.0800,
    height: 0.0523,
  ),
  _TapZone(
    part: 'back-hand-right',
    shape: 'ellipse',
    left: 0.6833,
    top: 0.4538,
    width: 0.0800,
    height: 0.0523,
  ),
  // Forearms  (path bbox x=75,y=226,w=19,h=70  &  x=206)
  _TapZone(
    part: 'back-forearm-left',
    left: 0.2500,
    top: 0.3477,
    width: 0.0633,
    height: 0.1077,
  ),
  _TapZone(
    part: 'back-forearm-right',
    left: 0.6867,
    top: 0.3477,
    width: 0.0633,
    height: 0.1077,
  ),
  // Glutes  (ellipse cx=126,cy=325,rx=23,ry=29  &  cx=174)
  _TapZone(
    part: 'back-glute-left',
    shape: 'ellipse',
    left: 0.3433,
    top: 0.4554,
    width: 0.1533,
    height: 0.0892,
  ),
  _TapZone(
    part: 'back-glute-right',
    shape: 'ellipse',
    left: 0.5033,
    top: 0.4554,
    width: 0.1533,
    height: 0.0892,
  ),
  // Lumbar  (rect x=136,y=260,w=28,h=44)
  _TapZone(
    part: 'back-lumbar',
    left: 0.4533,
    top: 0.4000,
    width: 0.0933,
    height: 0.0677,
  ),
  // Spine middle  (rect x=142,y=208,w=16,h=50)
  _TapZone(
    part: 'back-spine-middle',
    left: 0.4733,
    top: 0.3200,
    width: 0.0533,
    height: 0.0769,
  ),
  // Spine upper  (rect x=144,y=153,w=12,h=52)
  _TapZone(
    part: 'back-spine-upper',
    left: 0.4800,
    top: 0.2354,
    width: 0.0400,
    height: 0.0800,
  ),
  // Triceps  (ellipse cx=87,cy=192,rx=12,ry=30  &  cx=213)
  _TapZone(
    part: 'back-tricep-left',
    shape: 'ellipse',
    left: 0.2500,
    top: 0.2492,
    width: 0.0800,
    height: 0.0923,
  ),
  _TapZone(
    part: 'back-tricep-right',
    shape: 'ellipse',
    left: 0.6700,
    top: 0.2492,
    width: 0.0800,
    height: 0.0923,
  ),
  // Lats  (path bbox x=100,y=153,w=36,h=99  &  x=164)
  _TapZone(
    part: 'back-lat-left',
    left: 0.3333,
    top: 0.2354,
    width: 0.1200,
    height: 0.1523,
  ),
  _TapZone(
    part: 'back-lat-right',
    left: 0.5467,
    top: 0.2354,
    width: 0.1200,
    height: 0.1523,
  ),
  // Rear Deltoids  (path bbox x=72,y=113,w=38,h=57  &  x=190)
  _TapZone(
    part: 'back-shoulder-deltoid-left',
    left: 0.2400,
    top: 0.1738,
    width: 0.1267,
    height: 0.0877,
  ),
  _TapZone(
    part: 'back-shoulder-deltoid-right',
    left: 0.6333,
    top: 0.1738,
    width: 0.1267,
    height: 0.0877,
  ),
  // Trapezius  (path bbox x=110,y=106,w=80,h=44)
  _TapZone(
    part: 'back-trap-upper',
    left: 0.3667,
    top: 0.1631,
    width: 0.2667,
    height: 0.0677,
  ),
  // Neck  (rect x=137,y=79,w=26,h=26)
  _TapZone(
    part: 'back-neck',
    left: 0.4567,
    top: 0.1215,
    width: 0.0867,
    height: 0.0400,
  ),
  // Head  (ellipse cx=150,cy=45,rx=32,ry=38) — highest priority
  _TapZone(
    part: 'front-head',
    shape: 'ellipse',
    left: 0.3933,
    top: 0.0108,
    width: 0.2133,
    height: 0.1169,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// HIGHLIGHT OVERLAY PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightPainter extends CustomPainter {
  final List<_TapZone> zones;
  final List<String> selectedParts;
  final String? hoveredPart;

  _HighlightPainter({
    required this.zones,
    required List<String> selectedParts,
    required this.hoveredPart,
  }) : selectedParts = List<String>.unmodifiable(selectedParts);

  @override
  void paint(Canvas canvas, Size size) {
    for (final zone in zones) {
      final isSelected = selectedParts.contains(zone.part);
      final isHovered = hoveredPart == zone.part;
      if (!isSelected && !isHovered) continue;

      final fillPaint = Paint()
        ..color = isSelected
            ? OmniColors.freshMint.withValues(alpha: 0.40)
            : OmniColors.freshMint.withValues(alpha: 0.20)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = isSelected
            ? OmniColors.deepTeal
            : OmniColors.freshMint.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.5;

      final rect = Rect.fromLTWH(
        zone.left * size.width,
        zone.top * size.height,
        zone.width * size.width,
        zone.height * size.height,
      );

      if (zone.shape == 'ellipse') {
        canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, strokePaint);
      } else {
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));
        canvas.drawRRect(rr, fillPaint);
        canvas.drawRRect(rr, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      !listEquals(old.selectedParts, selectedParts) ||
      old.hoveredPart != hoveredPart ||
      old.zones != zones;
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY VIEW  (SVG image + fractional tap zones + highlight overlay)
// ─────────────────────────────────────────────────────────────────────────────

class _BodyView extends StatefulWidget {
  final bool isFront;
  final List<String> selectedParts;
  final void Function(String) onPartClick;

  const _BodyView({
    super.key,
    required this.isFront,
    required this.selectedParts,
    required this.onPartClick,
  });

  @override
  State<_BodyView> createState() => _BodyViewState();
}

class _BodyViewState extends State<_BodyView> {
  String? _hoveredPart;

  List<_TapZone> get _zones => widget.isFront ? _frontZones : _backZones;

  String? _hitTest(double fx, double fy) {
    // Reversed: last-defined zone has highest priority
    for (final zone in _zones.reversed) {
      if (zone.contains(fx, fy)) return zone.part;
    }
    return null;
  }

  String? _tapHit(Offset position, Size size) {
    final exact = _hitTest(position.dx / size.width, position.dy / size.height);
    if (exact != null) return exact;
    // Only extend into otherwise empty space; preserve precise zone priority.
    double nearestDistance = 6;
    String? nearest;
    for (final zone in _zones.reversed) {
      final rect = Rect.fromLTWH(
        zone.left * size.width,
        zone.top * size.height,
        zone.width * size.width,
        zone.height * size.height,
      );
      final closest = Offset(
        position.dx.clamp(rect.left, rect.right),
        position.dy.clamp(rect.top, rect.bottom),
      );
      final distance = (position - closest).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = zone.part;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    final svgAsset = widget.isFront
        ? 'assets/svg/body_front.svg'
        : 'assets/svg/body_back.svg';

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return MouseRegion(
          cursor: _hoveredPart == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onHover: (e) {
            final hit = _hitTest(
              e.localPosition.dx / w,
              e.localPosition.dy / h,
            );
            if (hit != _hoveredPart) setState(() => _hoveredPart = hit);
          },
          onExit: (_) => setState(() => _hoveredPart = null),
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTapUp: (e) {
              final hit = _tapHit(e.localPosition, Size(w, h));
              if (hit != null) widget.onPartClick(hit);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                SvgPicture.asset(
                  svgAsset,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                CustomPaint(
                  key: ValueKey(
                    widget.isFront ? 'front-highlights' : 'back-highlights',
                  ),
                  painter: _HighlightPainter(
                    zones: _zones,
                    selectedParts: widget.selectedParts,
                    hoveredPart: _hoveredPart,
                  ),
                ),
                for (final zone in _zones)
                  Positioned(
                    left: zone.left * w,
                    top: zone.top * h,
                    width: zone.width * w,
                    height: zone.height * h,
                    child: Semantics(
                      key: ValueKey(
                        '${widget.isFront ? 'front' : 'back'}-zone-${zone.part}',
                      ),
                      label: bodyAreaLabel(zone.part),
                      button: true,
                      selected: widget.selectedParts.contains(zone.part),
                      onTap: () => widget.onPartClick(zone.part),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class MuscleAnatomyMap extends StatelessWidget {
  final List<String> selectedParts;
  final void Function(String) onPartClick;
  final bool isFront;

  const MuscleAnatomyMap({
    super.key,
    required this.selectedParts,
    required this.onPartClick,
    this.isFront = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapWidth = math.min(
          math.max(0.0, constraints.maxWidth - 32),
          340.0,
        );
        return _buildCard(
          context,
          isFront ? 'Vue de Face' : 'Vue de Dos',
          isFront,
          mapWidth,
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    bool isFront,
    double mapWidth,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      padding: const EdgeInsets.all(OmniSpacing.base),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: OmniColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // AspectRatio matches SVG viewBox 300:650
          SizedBox(
            width: mapWidth,
            child: AspectRatio(
              aspectRatio: 300 / 650,
              child: _BodyView(
                key: ValueKey(
                  isFront ? 'emergency-body-front' : 'emergency-body-back',
                ),
                isFront: isFront,
                selectedParts: selectedParts,
                onPartClick: onPartClick,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Touchez une zone affectée',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
