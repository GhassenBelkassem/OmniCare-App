import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/omni_theme.dart';
import 'emergency_request_step1.dart';
import 'emergency_request_step2.dart';
import 'emergency_request_step3.dart';
import 'urgent_flow_mode.dart';

class EmergencyReviewScreen extends StatefulWidget {
  const EmergencyReviewScreen({
    super.key,
    required this.requestData,
    this.locationGateway = const DeviceEmergencyLocationGateway(),
    this.placesGateway,
    this.mapsEnabled = true,
  });

  final Map<String, dynamic> requestData;
  final EmergencyLocationGateway locationGateway;
  final EmergencyPlacesGateway? placesGateway;
  final bool mapsEnabled;

  @override
  State<EmergencyReviewScreen> createState() => _EmergencyReviewScreenState();
}

class _EmergencyReviewScreenState extends State<EmergencyReviewScreen> {
  late Map<String, dynamic> _requestData;

  @override
  void initState() {
    super.initState();
    _requestData = Map<String, dynamic>.from(widget.requestData);
  }

  Future<void> _editPatient() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => Material(
          color: OmniColors.pageBackground,
          child: EmergencyRequestStep1(
            flowMode: UrgentFlowMode.editFromReview,
            initialData: _requestData,
          ),
        ),
      ),
    );
    _applyUpdate(updated);
  }

  Future<void> _editSymptoms() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => Material(
          color: OmniColors.pageBackground,
          child: EmergencyRequestStep2(
            flowMode: UrgentFlowMode.editFromReview,
            step1Data: _requestData,
          ),
        ),
      ),
    );
    _applyUpdate(updated);
  }

  Future<void> _editLocation() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => Material(
          color: OmniColors.pageBackground,
          child: EmergencyRequestStep3(
            flowMode: UrgentFlowMode.editFromReview,
            previousData: _requestData,
            locationGateway: widget.locationGateway,
            placesGateway: widget.placesGateway,
            mapsEnabled: widget.mapsEnabled,
          ),
        ),
      ),
    );
    _applyUpdate(updated);
  }

  void _applyUpdate(Map<String, dynamic>? updated) {
    if (!mounted || updated == null) return;
    setState(() => _requestData = Map<String, dynamic>.from(updated));
  }

  void _sendUrgentRequest() {
    final consultationType =
        _requestData['consultationType'] as String? ?? 'home';
    final providerType = _requestData['providerType'] as String? ?? 'doctor';
    if (consultationType == 'home') {
      Navigator.pushNamed(
        context,
        '/doctor-selection',
        arguments: _requestData,
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/provider-list',
      arguments: {..._requestData, 'providerType': providerType},
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('emergency-review-page-surface'),
    color: OmniColors.pageBackground,
    child: Column(
      children: [
        _ReviewHeader(onBack: () => Navigator.maybePop(context)),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('emergency-review-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Vérifiez votre demande',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: OmniColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vérifiez les informations avant d’envoyer votre demande.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OmniColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PatientReviewSection(
                      data: _requestData,
                      onEdit: _editPatient,
                    ),
                    const SizedBox(height: 12),
                    _SymptomsReviewSection(
                      data: _requestData,
                      onEdit: _editSymptoms,
                    ),
                    const SizedBox(height: 12),
                    _LocationReviewSection(
                      data: _requestData,
                      onEdit: _editLocation,
                      mapsEnabled: widget.mapsEnabled,
                    ),
                    const SizedBox(height: 12),
                    const _AfterSendSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
        _ReviewFooter(onPressed: _sendUrgentRequest),
      ],
    ),
  );
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Retour',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Text(
            'Demande urgente',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OmniColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.icon,
    required this.child,
    required this.onEdit,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
    key: key,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: OmniColors.surfacePrimary,
      border: Border.all(color: OmniColors.borderLight),
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: OmniColors.slateBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: OmniColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Modifier'),
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _PatientReviewSection extends StatelessWidget {
  const _PatientReviewSection({required this.data, required this.onEdit});

  final Map<String, dynamic> data;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final patientType = data['patientType']?.toString();
    final patientName = patientType == 'me'
        ? 'Moi'
        : data['patientName']?.toString().trim();
    final name = patientName?.isNotEmpty == true ? patientName! : 'Patient';
    final relationship = data['relationship']?.toString().trim();
    return _ReviewSection(
      key: const ValueKey('review-patient-section'),
      title: 'Patient',
      icon: Icons.person_outline,
      onEdit: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: OmniColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (relationship?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              relationship!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SymptomsReviewSection extends StatelessWidget {
  const _SymptomsReviewSection({required this.data, required this.onEdit});

  final Map<String, dynamic> data;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final bodyParts = (data['bodyParts'] as List?)
        ?.map((part) => part.toString())
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    final description = (data['description'] ?? data['symptoms'])
        ?.toString()
        .trim();
    final pain = (data['painLevel'] as num?)?.round();
    final sharedPassport = data['shareMedicalRecord'] == true;
    return _ReviewSection(
      key: const ValueKey('review-symptoms-section'),
      title: 'Symptômes',
      icon: Icons.healing_outlined,
      onEdit: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bodyParts?.isNotEmpty == true)
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: bodyParts!
                    .map(
                      (part) => ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: OmniColors.infoBlueSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: OmniColors.borderLight),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Text(
                              part,
                              softWrap: true,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: OmniColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          if (pain != null) ...[
            if (bodyParts?.isNotEmpty == true) const SizedBox(height: 12),
            Text(
              'Douleur : $pain/10',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OmniColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (description?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OmniColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          if (sharedPassport) ...[
            const SizedBox(height: 12),
            Text(
              'Passeport médical partagé',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.deepTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationReviewSection extends StatelessWidget {
  const _LocationReviewSection({
    required this.data,
    required this.onEdit,
    required this.mapsEnabled,
  });

  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final bool mapsEnabled;

  @override
  Widget build(BuildContext context) {
    final location = SelectedConsultationLocation.fromPayload(data['location']);
    final address = location?.formattedAddress ?? data['address']?.toString();
    final instructions = ((data['location'] as Map?)?['arrivalInstructions'])
        ?.toString()
        .trim();
    return _ReviewSection(
      key: const ValueKey('review-location-section'),
      title: "Lieu d'intervention",
      icon: Icons.location_on_outlined,
      onEdit: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (address?.trim().isNotEmpty == true)
            Text(
              address!,
              softWrap: true,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OmniColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            )
          else
            Text(
              'Aucun lieu sélectionné',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
            ),
          if (instructions?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              instructions!,
              softWrap: true,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (location?.isDebugWebManualFallback == true) ...[
            const SizedBox(height: 12),
            const _ReviewInfoMessage(
              text: 'La position exacte sera résolue sur Android.',
            ),
          ],
          if (location?.hasCoordinates == true && mapsEnabled) ...[
            const SizedBox(height: 12),
            _ReviewMapPreview(location: location!),
          ],
        ],
      ),
    );
  }
}

class _ReviewMapPreview extends StatelessWidget {
  const _ReviewMapPreview({required this.location});

  final SelectedConsultationLocation location;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(OmniRadii.field),
    child: SizedBox(
      height: 160,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(location.latitude!, location.longitude!),
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('review-consultation-location'),
            position: LatLng(location.latitude!, location.longitude!),
          ),
        },
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        rotateGesturesEnabled: false,
        scrollGesturesEnabled: false,
        tiltGesturesEnabled: false,
      ),
    ),
  );
}

class _ReviewInfoMessage extends StatelessWidget {
  const _ReviewInfoMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: OmniColors.infoBlueSoft,
      borderRadius: BorderRadius.circular(OmniRadii.field),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: OmniColors.textSecondary,
        height: 1.4,
      ),
    ),
  );
}

class _AfterSendSection extends StatelessWidget {
  const _AfterSendSection();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('review-after-send-section'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: OmniColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Après l'envoi",
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: OmniColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Votre demande sera transmise aux médecins disponibles pouvant intervenir dans votre zone.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OmniColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}

class _ReviewFooter extends StatelessWidget {
  const _ReviewFooter({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: OmniColors.surfacePrimary,
      border: Border(top: BorderSide(color: OmniColors.borderLight)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                key: const ValueKey('emergency-review-send'),
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmniColors.primaryAction,
                  foregroundColor: OmniColors.textOnDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Envoyer la demande urgente'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
