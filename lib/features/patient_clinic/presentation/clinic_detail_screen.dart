import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/request_core/application/request_submission_controller.dart';
import '../application/patient_clinic_directory_controller.dart';
import '../data/patient_clinic_models.dart';
import 'widgets/clinic_gallery.dart';

/// Full-screen clinic detail for the patient directory.
///
/// Renders the gallery, name, location, availability and an About section. The
/// backend does not expose a services vocabulary to patients in V1, so there
/// is no services section. When the clinic is not accepting requests the
/// selection CTA is disabled with a plain explanation.
class ClinicDetailScreen extends StatefulWidget {
  const ClinicDetailScreen({super.key, required this.clinicId});

  final String clinicId;

  @override
  State<ClinicDetailScreen> createState() => _ClinicDetailScreenState();
}

class _ClinicDetailScreenState extends State<ClinicDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PatientClinicDirectoryController>().fetchDetail(
      widget.clinicId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<PatientClinicDirectoryController>();
    final request = context.watch<RequestSubmissionController>();
    final detail = directory.detail;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  _AppBar(detail: detail, clinicId: widget.clinicId),
                  if (directory.isLoadingDetail && detail == null)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (directory.detailError != null && detail == null)
                    SliverFillRemaining(
                      child: _DetailError(
                        message:
                            directory.detailError?.message ??
                            'Unable to load this clinic.',
                        onRetry: () => directory.fetchDetail(widget.clinicId),
                      ),
                    )
                  else if (detail != null)
                    SliverToBoxAdapter(child: _Content(detail: detail)),
                ],
              ),
            ),
            if (detail != null)
              _SelectBar(
                accepting: detail.acceptingRequests,
                onSelect: () {
                  request.selectClinic(detail.clinicId);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({this.detail, required this.clinicId});

  final PatientClinicDetail? detail;
  final String clinicId;

  @override
  Widget build(BuildContext context) {
    final clinic = detail;
    final images = clinic == null
        ? const <PatientClinicImage>[]
        : clinic.gallery.isNotEmpty
        ? clinic.gallery
        : clinic.primaryImageUrl == null
        ? const <PatientClinicImage>[]
        : [PatientClinicImage(imageUrl: clinic.primaryImageUrl!)];
    return SliverAppBar(
      pinned: true,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: const BackButton(color: Color(0xFF1D2939)),
      ),
      expandedHeight: detail == null ? 0 : 240,
      flexibleSpace: detail != null
          ? FlexibleSpaceBar(
              background: ClinicGallery(images: images, height: 240),
            )
          : null,
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.detail});

  final PatientClinicDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationParts = <String>[];
    if (detail.address != null && detail.address!.trim().isNotEmpty) {
      locationParts.add(detail.address!);
    }
    final cityGov = <String>[
      if (detail.city != null) detail.city!,
      if (detail.governorate != null) detail.governorate!,
    ].join(', ');
    if (cityGov.isNotEmpty) locationParts.add(cityGov);
    final location = locationParts.join('\n');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.location_on_outlined,
            title: 'Location',
            value: location.isEmpty ? 'Not specified' : location,
          ),
          const SizedBox(height: 12),
          _AvailabilityBanner(accepting: detail.acceptingRequests),
          if (detail.about != null && detail.about!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'About',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D2939),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail.about!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF475467),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1FBF9A), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF98A2B3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1D2939),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBanner extends StatelessWidget {
  const _AvailabilityBanner({required this.accepting});

  final bool accepting;

  @override
  Widget build(BuildContext context) {
    final color = accepting ? const Color(0xFF1FBF9A) : const Color(0xFFD0A21A);
    final bg = accepting
        ? const Color(0xFF1FBF9A).withOpacity(0.1)
        : const Color(0xFFD0A21A).withOpacity(0.1);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            accepting ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              accepting
                  ? 'This clinic is accepting new requests.'
                  : 'New requests are currently unavailable at this clinic.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectBar extends StatelessWidget {
  const _SelectBar({required this.accepting, required this.onSelect});

  final bool accepting;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: accepting ? onSelect : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1FBF9A),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFD0D5DD),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              accepting ? 'Select this clinic' : 'Not accepting requests',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Color(0xFFD92D20)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Color(0xFF475467)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
