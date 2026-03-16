import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/patients_api.dart';
import '../../core/models/patient_models.dart';

class PatientPickerScreen extends StatefulWidget {
  final bool forDoctor;

  const PatientPickerScreen({super.key, this.forDoctor = false});

  @override
  State<PatientPickerScreen> createState() => _PatientPickerScreenState();
}

class _PatientPickerScreenState extends State<PatientPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<PatientSummary>> _future;

  @override
  void initState() {
    super.initState();
    final api = PatientsApi();
    _future = widget.forDoctor
        ? api.getPatientsForProfessional()
        : api.getPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PatientSummary> _filter(List<PatientSummary> list) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return list;

    return list.where((p) {
      return p.displayName.toLowerCase().contains(q) ||
          p.patientId.toLowerCase().contains(q) ||
          (p.userId ?? '').toLowerCase().contains(q) ||
          (p.familyMemberId ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Patient',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by name or ID',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<PatientSummary>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load patients: ${snapshot.error}',
                          style: GoogleFonts.plusJakartaSans(),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final list = _filter(snapshot.data ?? const []);
                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          'No patients found',
                          style: GoogleFonts.plusJakartaSans(),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final p = list[index];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(context, p.patientId);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.displayName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1D2939),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'patientId: ${p.patientId}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: const Color(0xFF667085),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'type: ${p.type}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: const Color(0xFF667085),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
