import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/request_core/application/request_submission_controller.dart';
import '../application/patient_clinic_directory_controller.dart';
import 'clinic_detail_screen.dart';
import 'widgets/clinic_card.dart';

/// Patient clinic directory: real backend Clinics, search, pagination.
///
/// Selects nothing on its own — it records the chosen clinic on
/// [RequestSubmissionController] only via the detail screen's CTA, and shows
/// the current selection so the patient can continue to the next step. The
/// directory controller handles debounced, cancel-safe search and `Slice`
/// pagination, so this screen never loads every clinic.
class ClinicDirectoryScreen extends StatefulWidget {
  const ClinicDirectoryScreen({super.key});

  @override
  State<ClinicDirectoryScreen> createState() => _ClinicDirectoryScreenState();
}

class _ClinicDirectoryScreenState extends State<ClinicDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final controller = context.read<PatientClinicDirectoryController>();
    if (controller.items.isEmpty &&
        controller.status == PatientClinicDirectoryStatus.idle) {
      controller.loadFirst();
    }
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final controller = context.read<PatientClinicDirectoryController>();
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      controller.loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<PatientClinicDirectoryController>();
    final request = context.watch<RequestSubmissionController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Choose a clinic',
          style: TextStyle(
            color: Color(0xFF1D2939),
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: const BackButton(color: Color(0xFF1D2939)),
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            onChanged: directory.search,
          ),
          Expanded(
            child: _Body(
              directory: directory,
              selectedClinicId: request.selectedClinicId,
            ),
          ),
          if (request.selectedClinicId != null)
            _ContinueBar(
              onContinue: () {
                Navigator.of(context).pushNamed('/m05/situation');
              },
            ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search clinics',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF98A2B3)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        textInputAction: TextInputAction.search,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.directory, this.selectedClinicId});

  final PatientClinicDirectoryController directory;
  final String? selectedClinicId;

  @override
  Widget build(BuildContext context) {
    final status = directory.status;

    if (status == PatientClinicDirectoryStatus.loadingFirst &&
        directory.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == PatientClinicDirectoryStatus.error &&
        directory.items.isEmpty) {
      return _ErrorState(
        message: directory.error?.message ?? 'Unable to load clinics.',
        onRetry: directory.loadFirst,
      );
    }

    if (status == PatientClinicDirectoryStatus.empty &&
        directory.items.isEmpty) {
      return _EmptyState(query: directory.query);
    }

    final items = directory.items;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length + (directory.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final clinic = items[index];
        return ClinicListCard(
          clinic: clinic,
          selected: clinic.clinicId == selectedClinicId,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ClinicDetailScreen(clinicId: clinic.clinicId),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.query = ''});

  final String query;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_hospital_outlined,
              size: 56,
              color: Color(0xFF98A2B3),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No clinics found' : 'No clinics available',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D2939),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search.'
                  : 'Check back later for open clinics.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF667085)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.onContinue});

  final VoidCallback onContinue;

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
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1FBF9A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
