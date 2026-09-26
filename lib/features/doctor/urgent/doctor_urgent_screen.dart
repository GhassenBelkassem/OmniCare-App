import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/omni_theme.dart';
import 'doctor_urgent_controller.dart';
import 'doctor_urgent_map.dart';
import 'doctor_urgent_qr_scanner_screen.dart';
import 'doctor_urgent_web_map_support.dart';

class DoctorUrgentScreen extends StatelessWidget {
  const DoctorUrgentScreen({
    super.key,
    required this.controller,
    this.onOpenQr,
  });
  final DoctorUrgentController controller;
  final VoidCallback? onOpenQr;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final s = controller.state;
      final r = controller.request;
      final reveal = controller.identityRevealed;
      final online = s != DoctorUrgentState.offline;
      final motion = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Urgences',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Gérez vos demandes urgentes et visites à domicile.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
            ),
            const SizedBox(height: 20),
            AnimatedContainer(
              duration: motion,
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(OmniRadii.card),
                border: Border.all(color: OmniColors.borderLight),
                boxShadow: const [OmniColors.shadowCard],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: online
                        ? OmniColors.mintSoft
                        : OmniColors.slateSoft,
                    child: Icon(
                      Icons.emergency_outlined,
                      color: online
                          ? OmniColors.deepTeal
                          : OmniColors.slateBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          online
                              ? 'Disponible pour les urgences'
                              : 'Hors ligne',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          online
                              ? 'Vous recevez les demandes à proximité.'
                              : 'Passez en ligne pour recevoir des demandes.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: OmniColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: online,
                    onChanged: (v) =>
                        v ? controller.goOnline() : controller.goOffline(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: motion,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(0, .015), end: Offset.zero),
                  ),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey('urgent-main-state-${s.name}'),
                child: _card(context, s, r, reveal),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Visites récentes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const _Visits(),
          ],
        ),
      );
    },
  );
  Widget _card(
    BuildContext c,
    DoctorUrgentState s,
    DoctorUrgentRequest r,
    bool reveal,
  ) {
    final offline = s == DoctorUrgentState.offline,
        available = s == DoctorUrgentState.available,
        offer = s == DoctorUrgentState.offerReceived;
    if (available) return _availableRequests(c);
    if (s == DoctorUrgentState.acceptedWaitingPatient) {
      return _waitingCard(c);
    }
    if (s == DoctorUrgentState.selected) {
      return _selectedPatientCard(c, r);
    }
    if (s == DoctorUrgentState.enRoute) {
      return _enRouteContent(c, r);
    }
    final title = offline
        ? 'Vous êtes hors ligne'
        : available
        ? 'Vous êtes disponible'
        : offer
        ? 'Nouvelle demande urgente'
        : s == DoctorUrgentState.acceptedWaitingPatient
        ? 'Proposition envoyée'
        : s == DoctorUrgentState.selected
        ? 'Médecin sélectionné'
        : s == DoctorUrgentState.enRoute
        ? 'Intervention en cours'
        : 'Vous êtes arrivé';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: offer ? OmniColors.urgentCoralSoft : Colors.white,
        borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
        border: Border.all(color: OmniColors.borderLight),
        boxShadow: const [OmniColors.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              style: Theme.of(
                c,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          if (offline || available)
            Center(
              child: Text(
                offline
                    ? 'Activez votre disponibilité pour recevoir de nouvelles demandes urgentes.'
                    : 'Vous pouvez recevoir de nouvelles demandes urgentes.',
                textAlign: TextAlign.center,
              ),
            ),
          if (!offline && !available) ...[
            const SizedBox(height: 16),
            if (reveal)
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: OmniColors.mintSoft,
                    child: const Text('AC'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r.patientName!,
                    style: Theme.of(c).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              )
            else
              Text(
                '${r.age} ans',
                style: Theme.of(
                  c,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            const SizedBox(height: 8),
            Text(
              r.complaint,
              style: Theme.of(
                c,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text('Symptômes signalés : ${r.symptoms.join(' · ')}'),
            const SizedBox(height: 8),
            Text(reveal ? r.address! : '${r.area}\n${r.distance} · ${r.eta}'),
            if (!reveal) Text('Demande : ${r.id}'),
            if (offer)
              Text(
                'Réponse dans ${controller.countdownLabel}',
                style: Theme.of(c).textTheme.labelLarge?.copyWith(
                  color: OmniColors.urgentCoral,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
          const SizedBox(height: 20),
          Center(child: _action(c, s)),
        ],
      ),
    );
  }

  Widget _waitingCard(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
      border: Border.all(color: OmniColors.borderLight),
      boxShadow: const [OmniColors.shadowCard],
    ),
    child: Semantics(
      label: 'Proposition envoyée. En attente du patient.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: OmniColors.mintSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: OmniColors.deepTeal,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Proposition envoyée',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Le patient choisit actuellement son médecin.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: OmniColors.mintSoft,
                borderRadius: BorderRadius.circular(OmniRadii.pill),
              ),
              child: Text(
                'En attente du patient',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: OmniColors.deepTeal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Patient · 45 ans',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Douleur thoracique sévère',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 17,
                color: OmniColors.slateBlue,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'À proximité de Tunis\n1,8 km · environ 6 min',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'OMN-2026-1847',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: OmniColors.textSecondary),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 14),
            const Divider(color: OmniColors.borderLight),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: controller.simulateSelection,
                child: const Text('Simuler la sélection du patient'),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _selectedPatientCard(
    BuildContext context,
    DoctorUrgentRequest r,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
      border: Border.all(color: OmniColors.borderLight),
      boxShadow: const [OmniColors.shadowCard],
    ),
    child: Semantics(
      label:
          'Patient confirmé. ${r.patientName}. ${r.address?.replaceAll('\n', ', ')}. ${r.distance}. ETA 6 min.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: OmniColors.deepTeal,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'PATIENT CONFIRMÉ',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: OmniColors.deepTeal,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .4,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.patientName!,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.age} ans',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Douleur thoracique sévère',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OmniColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 22,
                backgroundColor: OmniColors.mintSoft,
                child: Text(
                  'AC',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: OmniColors.deepTeal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: OmniColors.mintSoft,
              borderRadius: BorderRadius.circular(OmniRadii.card),
              border: Border.all(
                color: OmniColors.freshMint.withValues(alpha: .2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: OmniColors.deepTeal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.address!.replaceAll('\n', ', '),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.distance} · ETA 6 min',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: controller.startRoute,
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Démarrer le trajet'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'La messagerie sera disponible prochainement.',
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: OmniColors.borderStrong),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _availableRequests(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Nouvelles demandes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Semantics(
            label: '2 nouvelles demandes',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: OmniColors.urgentCoralSoft,
                borderRadius: BorderRadius.circular(OmniRadii.pill),
              ),
              child: Text(
                '2',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: OmniColors.urgentCoral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
          border: Border.all(
            color: OmniColors.urgentCoral.withValues(alpha: .22),
          ),
          boxShadow: const [OmniColors.shadowCard],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OmniRadii.cardLarge - 1),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: OmniColors.urgentCoral),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: OmniColors.urgentCoral,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'URGENT · OMN-2026-1847',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: OmniColors.urgentCoral,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        Text(
                          '${controller.countdownLabel}s',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: OmniColors.urgentCoral,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Patient · 45 ans',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Douleur thoracique sévère',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Douleur thoracique intense · Difficulté à respirer',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: OmniColors.slateBlue,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'À proximité de Tunis · 1,8 km · ~6 min',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: OmniColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        TextButton(
                          onPressed: controller.showOffer,
                          child: const Text('Refuser'),
                        ),
                        TextButton(
                          onPressed: () => _showRequestSheet(context),
                          child: const Text('Voir'),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 108,
                          child: FilledButton(
                            onPressed: () {
                              controller.showOffer();
                              controller.accept();
                            },
                            child: const Text('Accepter'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        '1 autre demande à proximité',
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: OmniColors.textSecondary),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(OmniRadii.card),
          border: Border.all(color: OmniColors.borderLight),
          boxShadow: const [OmniColors.shadowSm],
        ),
        child: Row(
          children: [
            const Icon(Icons.circle, color: OmniColors.urgentCoral, size: 8),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient · 61 ans',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Malaise et vertiges importants · 3,4 km',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: OmniColors.textTertiary,
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _showRequestSheet(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => _UrgentRequestSheet(
          controller: controller,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      );

  Widget _enRouteContent(BuildContext context, DoctorUrgentRequest r) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        label: 'En route vers le patient. ${r.distance}. Environ 6 minutes.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.navigation_rounded,
                  size: 17,
                  color: OmniColors.deepTeal,
                ),
                const SizedBox(width: 6),
                Text(
                  'EN ROUTE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: OmniColors.deepTeal,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'En route vers le patient',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${r.distance} · environ 6 min',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _UrgentRouteMap(onOpenMaps: () => unawaited(_openMaps(context))),
      const SizedBox(height: 16),
      _enRoutePatientCard(context, r),
      const SizedBox(height: 12),
      _visitReasonCard(context),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: controller.arrive,
          icon: const Icon(Icons.location_on_rounded),
          label: const Text('Je suis arrivé'),
        ),
      ),
    ],
  );

  Widget _enRoutePatientCard(
    BuildContext context,
    DoctorUrgentRequest r,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
      border: Border.all(color: OmniColors.borderLight),
      boxShadow: const [OmniColors.shadowCard],
    ),
    child: Semantics(
      label:
          'Patient Amina Chaari, ${r.age} ans. ${r.address?.replaceAll('\n', ', ')}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: OmniColors.mintSoft,
                child: Text(
                  'AC',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: OmniColors.deepTeal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.patientName} · ${r.age} ans',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: OmniColors.slateBlue,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            r.address!.replaceAll('\n', ', '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: OmniColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Envoyer un message à Amina Chaari',
                  child: OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'La messagerie sera disponible prochainement.',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Message'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Ouvrir l’itinéraire dans Google Maps',
                  child: OutlinedButton.icon(
                    onPressed: () => unawaited(_openMaps(context)),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Maps'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _visitReasonCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
      border: Border.all(color: OmniColors.borderLight),
      boxShadow: const [OmniColors.shadowCard],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: OmniColors.urgentCoralSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_information_outlined,
                size: 18,
                color: OmniColors.urgentCoral,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Motif de la visite',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Douleur thoracique sévère',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (final symptom in const [
          'Douleur thoracique intense',
          'Difficulté à respirer',
          'Nausées',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(
                    Icons.circle,
                    size: 5,
                    color: OmniColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    symptom,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Future<void> _openMaps(BuildContext context) async {
    final opened = await DoctorUrgentMapDemo.openExternalDirections();
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir Google Maps.')),
      );
    }
  }

  Widget _action(BuildContext c, DoctorUrgentState s) => switch (s) {
    DoctorUrgentState.offline => FilledButton(
      onPressed: controller.goOnline,
      child: const Text('Passer en ligne'),
    ),
    DoctorUrgentState.available => TextButton(
      onPressed: controller.showOffer,
      child: const Text('Voir la demande de démonstration'),
    ),
    DoctorUrgentState.offerReceived => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          child: OutlinedButton(
            onPressed: controller.decline,
            child: const Text('Refuser'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: FilledButton(
            onPressed: controller.accept,
            child: const Text('Accepter'),
          ),
        ),
      ],
    ),
    DoctorUrgentState.acceptedWaitingPatient => TextButton(
      onPressed: controller.simulateSelection,
      child: const Text('Simuler la sélection du patient'),
    ),
    DoctorUrgentState.selected => FilledButton(
      onPressed: controller.startRoute,
      child: const Text('Démarrer le trajet'),
    ),
    DoctorUrgentState.enRoute => FilledButton(
      onPressed: controller.arrive,
      child: const Text('Je suis arrivé'),
    ),
    DoctorUrgentState.arrived => FilledButton(
      onPressed:
          onOpenQr ??
          () => Navigator.of(c).push(
            MaterialPageRoute(
              builder: (_) =>
                  DoctorUrgentQrScannerScreen(request: controller.request),
            ),
          ),
      child: const Text('Scanner le QR du patient'),
    ),
  };
}

class _UrgentRouteMap extends StatefulWidget {
  const _UrgentRouteMap({required this.onOpenMaps});

  final VoidCallback onOpenMaps;

  @override
  State<_UrgentRouteMap> createState() => _UrgentRouteMapState();
}

class _UrgentRouteMapState extends State<_UrgentRouteMap> {
  Timer? _fallbackTimer;
  Timer? _webReadinessTimer;
  bool _mapReady = false;
  bool _mapUnavailable = false;
  bool _webApiReady = !kIsWeb;

  @override
  void initState() {
    super.initState();
    _fallbackTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_mapReady) {
        setState(() => _mapUnavailable = true);
      }
    });
    if (kIsWeb && !isGoogleMapsJavaScriptLoaded) {
      _webReadinessTimer = Timer.periodic(const Duration(milliseconds: 200), (
        timer,
      ) {
        if (isGoogleMapsJavaScriptLoaded) {
          timer.cancel();
          if (mounted) setState(() => _webApiReady = true);
        }
      });
    } else {
      _webApiReady = true;
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _webReadinessTimer?.cancel();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController _) {
    _fallbackTimer?.cancel();
    if (mounted) setState(() => _mapReady = true);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Carte de l’itinéraire vers le patient',
    child: Container(
      height: 218,
      decoration: BoxDecoration(
        color: OmniColors.slateSoft,
        borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
        border: Border.all(color: OmniColors.borderLight),
        boxShadow: const [OmniColors.shadowCard],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OmniRadii.cardLarge - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_mapUnavailable)
              _MapFallback(onOpenMaps: widget.onOpenMaps)
            else if (_webApiReady)
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: DoctorUrgentMapDemo.patientDestination,
                  zoom: 14.3,
                ),
                onMapCreated: _onMapCreated,
                markers: {
                  Marker(
                    markerId: const MarkerId('doctor-origin'),
                    position: DoctorUrgentMapDemo.doctorOrigin,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueCyan,
                    ),
                  ),
                  Marker(
                    markerId: const MarkerId('patient-destination'),
                    position: DoctorUrgentMapDemo.patientDestination,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                  ),
                },
                polylines: {
                  const Polyline(
                    polylineId: PolylineId('demo-route'),
                    points: DoctorUrgentMapDemo.route,
                    color: OmniColors.deepTeal,
                    width: 5,
                  ),
                },
                compassEnabled: false,
                mapToolbarEnabled: false,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomControlsEnabled: false,
                webGestureHandling: WebGestureHandling.cooperative,
              ),
            if (!_mapReady && !_mapUnavailable)
              const ColoredBox(
                color: OmniColors.slateSoft,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 8),
                      Text('Chargement de la carte…'),
                    ],
                  ),
                ),
              ),
            if (!_mapUnavailable && _mapReady) ...[
              Positioned(
                top: 12,
                left: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(OmniRadii.pill),
                    boxShadow: const [OmniColors.shadowSm],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.navigation_rounded,
                          size: 15,
                          color: OmniColors.deepTeal,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '6 min · 1,8 km',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Semantics(
                  button: true,
                  label: 'Ouvrir l’itinéraire dans Google Maps',
                  child: OutlinedButton.icon(
                    onPressed: widget.onOpenMaps,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Ouvrir dans Maps'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: OmniColors.slateBlue,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({required this.onOpenMaps});

  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: OmniColors.slateSoft,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.map_outlined,
              color: OmniColors.slateBlue,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              'Carte indisponible',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Utilisez Google Maps pour continuer l’itinéraire.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenMaps,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Ouvrir dans Maps'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _UrgentRequestSheet extends StatelessWidget {
  const _UrgentRequestSheet({required this.controller, required this.onClose});
  final DoctorUrgentController controller;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      // This sheet is closed explicitly by its action handlers. In particular,
      // do not schedule another Navigator.pop() after an accept state change:
      // the accept handler already dismisses this modal, and a second pop can
      // dismiss the Urgences route itself.
      if (controller.state != DoctorUrgentState.available) {
        return const SizedBox.shrink();
      }
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: OmniColors.urgentCoral,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'URGENT · OMN-2026-1847',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: OmniColors.urgentCoral,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                'Demande de visite urgente',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: OmniColors.slateSoft,
                    child: Text('?'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient · 45 ans',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Text('Identité non disponible'),
                      ],
                    ),
                  ),
                  Text(
                    controller.countdownLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: OmniColors.urgentCoral,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: OmniColors.urgentCoral.withValues(alpha: .22),
                  ),
                  borderRadius: BorderRadius.circular(OmniRadii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MOTIF',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: OmniColors.urgentCoral,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Douleur thoracique sévère',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Chip(label: Text('Douleur thoracique intense')),
                        Chip(label: Text('Difficulté à respirer')),
                        Chip(label: Text('Nausées')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: OmniColors.slateSoft,
                  borderRadius: BorderRadius.circular(OmniRadii.card),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: OmniColors.slateBlue,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'À proximité de Tunis\n1,8 km · environ 6 min',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "L'identité et l'adresse exacte seront disponibles si le patient vous sélectionne.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        controller.decline();
                        onClose();
                      },
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        controller.showOffer();
                        controller.accept();
                        onClose();
                      },
                      child: const Text('Accepter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Visits extends StatelessWidget {
  const _Visits();
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('urgent-recent-visits-card'),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
      boxShadow: const [OmniColors.shadowCard],
    ),
    child: const Column(
      children: [
        _VisitRow(
          'SB',
          'Aujourd’hui · 08:15',
          'Sami Ben Ali',
          'Fièvre élevée · Terminée',
        ),
        Divider(height: 1),
        _VisitRow(
          'NM',
          'Hier · 19:40',
          'Nadia Mansour',
          'Douleur abdominale · Terminée',
        ),
        Divider(height: 1),
        _VisitRow(
          'HG',
          'Samedi · 14:10',
          'Hatem Gharbi',
          'Visite à domicile · Terminée',
        ),
      ],
    ),
  );
}

class _VisitRow extends StatelessWidget {
  const _VisitRow(this.initials, this.when, this.name, this.context);
  final String initials, when, name, context;
  @override
  Widget build(BuildContext c) => Semantics(
    label: '$when, $name, $context',
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.md,
        vertical: 10,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: OmniColors.slateSoft,
            child: Text(
              initials,
              style: Theme.of(c).textTheme.labelSmall?.copyWith(
                color: OmniColors.slateBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  when,
                  style: Theme.of(c).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textSecondary,
                  ),
                ),
                Text(
                  name,
                  style: Theme.of(
                    c,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  context,
                  style: Theme.of(c).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: OmniColors.textTertiary,
          ),
        ],
      ),
    ),
  );
}
