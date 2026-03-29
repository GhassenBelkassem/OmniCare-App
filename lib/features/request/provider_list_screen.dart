import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/api/doctors_api.dart';
import '../../core/api/consultations_api.dart';
import '../../providers/user_provider.dart';
import 'provider_map_screen.dart';

class ProviderListScreen extends StatefulWidget {
  final String providerType; // 'doctor' or 'kine'
  final String? initialVisitType;
  final bool initialIsEmergency;

  const ProviderListScreen({
    super.key,
    required this.providerType,
    this.initialVisitType,
    this.initialIsEmergency = false,
  });

  @override
  State<ProviderListScreen> createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends State<ProviderListScreen> {
  bool _isSearching = true;
  String _sortBy = 'distance'; // distance, rating, price
  double _minPrice = 0;
  double _maxPrice = 500;

  List<Map<String, dynamic>> _providers = const [];
  String? _loadError;

  List<Map<String, dynamic>> get _filteredAndSortedProviders {
    var filtered = _providers.where((provider) {
      final price = (provider['price'] as num?)?.toDouble() ?? 0.0;
      return price >= _minPrice && price <= _maxPrice;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'distance':
          final da = (a['distance'] as num?)?.toDouble() ?? 0.0;
          final db = (b['distance'] as num?)?.toDouble() ?? 0.0;
          return da.compareTo(db);
        case 'rating':
          final ra = (a['rating'] as num?)?.toDouble() ?? 0.0;
          final rb = (b['rating'] as num?)?.toDouble() ?? 0.0;
          return rb.compareTo(ra);
        case 'price':
          final pa = (a['price'] as num?)?.toDouble() ?? 0.0;
          final pb = (b['price'] as num?)?.toDouble() ?? 0.0;
          return pa.compareTo(pb);
        default:
          return 0;
      }
    });

    return filtered;
  }

  Future<bool> _hasHistoryWithProvider({required String providerId}) async {
    try {
      final items = await ConsultationsApi().listConsultations();
      return items.any((c) => (c.providerId ?? '').toString() == providerId);
    } catch (_) {
      return true;
    }
  }

  Future<bool> _promptImmediateIntervention() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Intervention Immédiate ?',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D2939),
            ),
          ),
          content: Text(
            "S'agit-il d'une urgence nécessitant un déplacement immédiat ?",
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF475467)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Non, planifier',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF667085),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                "Oui, c'est une urgence",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
    return res == true;
  }

  Future<bool> _promptImmediateEmergencyConsent() async {
    bool consent = false;
    final res = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Consentement requis',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Je consens à une visite immédiate et je confirme qu'il s'agit d'une urgence nécessitant une intervention.",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF475467),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setModalState(() {
                          consent = !consent;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: consent
                                ? const Color(0xFF1FBF9A)
                                : const Color(0xFFE2E8F0),
                          ),
                          color: consent
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFF9FAFB),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: consent
                                      ? const Color(0xFF1FBF9A)
                                      : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                                color: consent
                                    ? const Color(0xFF1FBF9A)
                                    : Colors.transparent,
                              ),
                              child: consent
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "J'accepte et je confirme",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1D2939),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF667085),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Annuler',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: consent
                                ? () => Navigator.pop(context, true)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1FBF9A),
                              disabledBackgroundColor: const Color(0xFFE2E8F0),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Continuer',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
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
      },
    );
    return res == true;
  }

  Future<String?> _promptVisitType() async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Text(
                  'Type de visite',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choisissez le type de consultation. La visite en clinique est recommandée.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                _VisitTypeTile(
                  title: 'Clinique',
                  subtitle: 'Recommandé',
                  leadingIcon: Icons.local_hospital_outlined,
                  badgeText: 'RECOMMENDED',
                  badgeColor: const Color(0xFF1FBF9A),
                  onTap: () => Navigator.pop(context, 'CLINIC'),
                ),
                const SizedBox(height: 10),
                _VisitTypeTile(
                  title: 'Visite à domicile',
                  subtitle: 'Déplacement du professionnel',
                  leadingIcon: Icons.home_outlined,
                  badgeText: 'HOME',
                  badgeColor: const Color(0xFFEF4444),
                  onTap: () => Navigator.pop(context, 'HOME'),
                ),
                const SizedBox(height: 10),
                _VisitTypeTile(
                  title: 'Téléconsultation',
                  subtitle: 'Appel vidéo / audio',
                  leadingIcon: Icons.videocam_outlined,
                  badgeText: 'VIDEO',
                  badgeColor: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.pop(context, 'TELECONSULTATION'),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTimeSelection(String providerId) async {
    final id = providerId.trim();
    debugPrint('[ProviderListScreen] _openTimeSelection providerId="$id"');
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid providerId',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final String? visitType =
        widget.initialVisitType ?? await _promptVisitType();
    if (!mounted) return;
    if (visitType == null) return;

    final hasHistory = await _hasHistoryWithProvider(providerId: id);
    if (!mounted) return;
    if (!hasHistory) {
      final wantsImmediate = await _promptImmediateIntervention();
      if (!mounted) return;
      if (wantsImmediate) {
        final ok = await _promptImmediateEmergencyConsent();
        if (!mounted) return;
        if (!ok) return;

        final userProvider = context.read<UserProvider>();
        final data = <String, dynamic>{
          'providerType': widget.providerType,
          'consultationType': 'home',
          'visitType': 'HOME',
          'isEmergency': true,
          'patientName': userProvider.user?.displayName,
        };

        Navigator.pushNamed(context, '/emergency-step3', arguments: data);
        return;
      }
    }

    final uuidLike = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuidLike.hasMatch(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Provider IDs are still mock ("$id"). UI will open, but submitting will fail until real backend IDs are wired.',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: const Color(0xFF0F6F73),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    try {
      Navigator.pushNamed(
        context,
        '/time-selection',
        arguments: {
          'providerId': id,
          'visitType': visitType,
          'isEmergency': widget.initialIsEmergency,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Navigation error: $e',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _isSearching = true;
      _loadError = null;
    });

    try {
      if (widget.providerType != 'doctor') {
        setState(() {
          _providers = const [];
          _isSearching = false;
          _loadError = 'Provider type not supported yet.';
        });
        return;
      }

      final doctors = await DoctorsApi().getDoctors();
      setState(() {
        _providers = doctors
            .map((d) {
              final years = (d['experienceYears'] as num?)?.toInt();
              final rating = (d['rating'] as num?)?.toDouble() ?? 0.0;
              final reviews = (d['totalReviews'] as num?)?.toInt() ?? 0;
              final fee =
                  (d['officeConsultationFee'] as num?)?.toDouble() ?? 0.0;
              return <String, dynamic>{
                'id': d['id']?.toString() ?? '',
                'name': d['name']?.toString() ?? '',
                'specialty': d['specialty']?.toString() ?? '',
                'rating': rating,
                'reviews': reviews,
                'distance': 0.0,
                'price': fee,
                'experience': years == null ? '' : '$years ans',
                'image': null,
              };
            })
            .toList(growable: false);
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _providers = const [];
        _isSearching = false;
        _loadError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.providerType == 'doctor'
        ? 'Health Providers'
        : 'Kinésithérapeutes';
    final providers = _filteredAndSortedProviders;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2939)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        actions: _isSearching
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.map, color: Color(0xFF1D2939)),
                  onPressed: () => _showMapView(),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, color: Color(0xFF1D2939)),
                  onPressed: () => _showFilterSheet(),
                ),
              ],
      ),
      body: _isSearching
          ? _buildSearchingScreen()
          : (_loadError != null && providers.isEmpty)
          ? _buildLoadError()
          : Column(
              children: [
                // Sort bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Trier par:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildSortChip('Distance', 'distance'),
                              const SizedBox(width: 8),
                              _buildSortChip('Note', 'rating'),
                              const SizedBox(width: 8),
                              _buildSortChip('Prix', 'price'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Provider list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: providers.length,
                    itemBuilder: (context, index) {
                      final provider = providers[index];
                      return _buildProviderCard(provider, false);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
            const SizedBox(height: 12),
            Text(
              _loadError ?? 'Failed to load providers',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF667085),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProviders,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(
                'Réessayer',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1FBF9A) : const Color(0xFFF4F5F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1FBF9A)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF667085),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider, bool isSelected) {
    final providerId = provider['id']?.toString() ?? '';
    final name = provider['name']?.toString() ?? '';
    final specialty = provider['specialty']?.toString() ?? '';
    final rating = (provider['rating'] as num?)?.toDouble() ?? 0.0;
    final reviews = (provider['reviews'] as num?)?.toInt() ?? 0;
    final distanceKm = (provider['distance'] as num?)?.toDouble() ?? 0.0;
    final price = (provider['price'] as num?)?.toDouble() ?? 0.0;
    final experience = provider['experience']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF1FBF9A) : const Color(0xFFE5E7EB),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openTimeSelection(providerId),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1FBF9A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D2939),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            specialty,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: const Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFBBF24),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(rating % 1 == 0 ? 0 : 1),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1D2939),
                                ),
                              ),
                              Text(
                                ' ($reviews)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFF667085),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${distanceKm.toStringAsFixed(1)} km',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1FBF9A,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${price.toStringAsFixed(0)} DT',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1FBF9A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                experience.isEmpty
                                    ? '—'
                                    : '$experience d\'expérience',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1FBF9A).withOpacity(0.12)
                              : const Color(0xFFF4F5F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1FBF9A)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: isSelected
                              ? const Color(0xFF1FBF9A)
                              : const Color(0xFF667085),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // More Details Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showProviderDetails(provider),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1FBF9A),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Plus de détails',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingScreen() {
    final String providerLabel = widget.providerType == 'doctor'
        ? 'health providers'
        : 'kinésithérapeutes';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF1FBF9A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Searching for $providerLabel...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we find the best match.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF667085),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showProviderDetails(Map<String, dynamic> provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider['name'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1D2939),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                provider['specialty'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            Icons.star,
                            '${provider['rating']}',
                            '${provider['reviews']} avis',
                            const Color(0xFFFBBF24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            Icons.location_on,
                            '${provider['distance']} km',
                            'Distance',
                            const Color(0xFF1FBF9A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            Icons.work_outline,
                            '${provider['experience']}',
                            'Expérience',
                            const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Price
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1FBF9A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF1FBF9A).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tarif de consultation',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F6F73),
                            ),
                          ),
                          Text(
                            '${provider['price']} DT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1FBF9A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // About Section
                    Text(
                      'À propos',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Professionnel de santé expérimenté avec ${provider['experience']} d\'expérience dans le domaine. Spécialisé en ${provider['specialty']}.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF667085),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Languages
                    Text(
                      'Langues parlées',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Français', 'Arabe', 'Anglais'].map((lang) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F5F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            lang,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF667085),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF667085),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showMapView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProviderMapScreen(
          providerType: widget.providerType,
          providers: _filteredAndSortedProviders,
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtres',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Fourchette de prix',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 12),
              RangeSlider(
                values: RangeValues(_minPrice, _maxPrice),
                min: 0,
                max: 500,
                divisions: 50,
                activeColor: const Color(0xFF1FBF9A),
                labels: RangeLabels(
                  '${_minPrice.round()} DT',
                  '${_maxPrice.round()} DT',
                ),
                onChanged: (values) {
                  setModalState(() {
                    _minPrice = values.start;
                    _maxPrice = values.end;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_minPrice.round()} DT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF667085),
                    ),
                  ),
                  Text(
                    '${_maxPrice.round()} DT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Appliquer les filtres',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitTypeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final String badgeText;
  final Color badgeColor;
  final VoidCallback onTap;

  const _VisitTypeTile({
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.badgeText,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(leadingIcon, color: badgeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1D2939),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: badgeColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
            ],
          ),
        ),
      ),
    );
  }
}
