import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'provider_map_screen.dart';
import 'request_submitted_screen.dart';

class ProviderListScreen extends StatefulWidget {
  final String providerType; // 'doctor' or 'kine'

  const ProviderListScreen({
    super.key,
    required this.providerType,
  });

  @override
  State<ProviderListScreen> createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends State<ProviderListScreen> {
  bool _isSearching = true;
  String _sortBy = 'distance'; // distance, rating, price
  double _minPrice = 0;
  double _maxPrice = 500;
  final List<String> _selectedProviders = [];
  Timer? _searchTimer;

  // Mock data for doctors
  final List<Map<String, dynamic>> _mockDoctors = [
    {
      'id': 'doc1',
      'name': 'Dr. Ahmed Mansour',
      'specialty': 'Cardiologue',
      'rating': 4.9,
      'reviews': 156,
      'distance': 1.2,
      'price': 250,
      'experience': '15 ans',
      'image': 'https://i.pravatar.cc/150?img=12',
    },
    {
      'id': 'doc2',
      'name': 'Dr. Fatima Zahra',
      'specialty': 'Généraliste',
      'rating': 4.8,
      'reviews': 203,
      'distance': 0.8,
      'price': 200,
      'experience': '10 ans',
      'image': 'https://i.pravatar.cc/150?img=45',
    },
    {
      'id': 'doc3',
      'name': 'Dr. Youssef Benali',
      'specialty': 'Neurologue',
      'rating': 4.95,
      'reviews': 89,
      'distance': 2.5,
      'price': 300,
      'experience': '20 ans',
      'image': 'https://i.pravatar.cc/150?img=33',
    },
    {
      'id': 'doc4',
      'name': 'Dr. Samira El Amrani',
      'specialty': 'Pédiatre',
      'rating': 4.7,
      'reviews': 178,
      'distance': 1.8,
      'price': 220,
      'experience': '12 ans',
      'image': 'https://i.pravatar.cc/150?img=47',
    },
    {
      'id': 'doc5',
      'name': 'Dr. Karim Alaoui',
      'specialty': 'Dermatologue',
      'rating': 4.85,
      'reviews': 134,
      'distance': 3.2,
      'price': 280,
      'experience': '18 ans',
      'image': 'https://i.pravatar.cc/150?img=51',
    },
    {
      'id': 'doc6',
      'name': 'Dr. Nadia Benjelloun',
      'specialty': 'Généraliste',
      'rating': 4.6,
      'reviews': 92,
      'distance': 0.5,
      'price': 180,
      'experience': '8 ans',
      'image': 'https://i.pravatar.cc/150?img=44',
    },
  ];

  // Mock data for physiotherapists
  final List<Map<String, dynamic>> _mockKines = [
    {
      'id': 'kine1',
      'name': 'Hassan Tazi',
      'specialty': 'Kinésithérapeute du Sport',
      'rating': 4.8,
      'reviews': 112,
      'distance': 1.5,
      'price': 180,
      'experience': '12 ans',
      'image': 'https://i.pravatar.cc/150?img=60',
    },
    {
      'id': 'kine2',
      'name': 'Leila Moussaoui',
      'specialty': 'Rééducation Orthopédique',
      'rating': 4.9,
      'reviews': 145,
      'distance': 0.9,
      'price': 200,
      'experience': '15 ans',
      'image': 'https://i.pravatar.cc/150?img=48',
    },
    {
      'id': 'kine3',
      'name': 'Omar Chakir',
      'specialty': 'Kinésithérapie Respiratoire',
      'rating': 4.7,
      'reviews': 87,
      'distance': 2.1,
      'price': 160,
      'experience': '10 ans',
      'image': 'https://i.pravatar.cc/150?img=56',
    },
    {
      'id': 'kine4',
      'name': 'Amina Berrada',
      'specialty': 'Rééducation Post-Opératoire',
      'rating': 4.85,
      'reviews': 156,
      'distance': 1.2,
      'price': 190,
      'experience': '14 ans',
      'image': 'https://i.pravatar.cc/150?img=43',
    },
    {
      'id': 'kine5',
      'name': 'Rachid Filali',
      'specialty': 'Kinésithérapie Générale',
      'rating': 4.65,
      'reviews': 98,
      'distance': 3.0,
      'price': 150,
      'experience': '9 ans',
      'image': 'https://i.pravatar.cc/150?img=68',
    },
  ];

  List<Map<String, dynamic>> get _providers {
    return widget.providerType == 'doctor' ? _mockDoctors : _mockKines;
  }

  List<Map<String, dynamic>> get _filteredAndSortedProviders {
    var filtered = _providers.where((provider) {
      return provider['price'] >= _minPrice && provider['price'] <= _maxPrice;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'distance':
          return a['distance'].compareTo(b['distance']);
        case 'rating':
          return b['rating'].compareTo(a['rating']);
        case 'price':
          return a['price'].compareTo(b['price']);
        default:
          return 0;
      }
    });

    return filtered;
  }

  void _toggleSelection(String providerId) {
    setState(() {
      if (_selectedProviders.contains(providerId)) {
        _selectedProviders.remove(providerId);
      } else {
        if (_selectedProviders.length < 5) {
          _selectedProviders.add(providerId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Vous pouvez sélectionner maximum 5 professionnels',
                style: GoogleFonts.plusJakartaSans(),
              ),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Start searching animation
    _searchTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _sendRequests() {
    if (_selectedProviders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez sélectionner au moins un professionnel',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Navigate to request submitted success screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestSubmittedScreen(
          providerCount: _selectedProviders.length,
          providerType: widget.providerType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.providerType == 'doctor' ? 'Docteurs' : 'Kinésithérapeutes';
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
        actions: _isSearching ? [] : [
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
      body: _isSearching ? _buildSearchingScreen() : Column(
        children: [
          // Sort bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                final isSelected = _selectedProviders.contains(provider['id']);
                return _buildProviderCard(provider, isSelected);
              },
            ),
          ),

          // Bottom bar with selection count and send button
          if (_selectedProviders.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1FBF9A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedProviders.length}/5 sélectionné(s)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1FBF9A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _sendRequests,
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
                          'Envoyer les demandes',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
            color: isSelected ? const Color(0xFF1FBF9A) : const Color(0xFFE5E7EB),
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
          onTap: () => _toggleSelection(provider['id']),
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
                            provider['name'],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D2939),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            provider['specialty'],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: const Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Color(0xFFFBBF24), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${provider['rating']}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1D2939),
                                ),
                              ),
                              Text(
                                ' (${provider['reviews']})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.location_on, color: Color(0xFF667085), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${provider['distance']} km',
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1FBF9A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${provider['price']} DH',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1FBF9A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${provider['experience']} d\'expérience',
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
    final String providerLabel = widget.providerType == 'doctor' ? 'docteurs' : 'kinésithérapeutes';
    
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
                Icon(
                  widget.providerType == 'doctor' ? Icons.medical_services : Icons.accessibility_new,
                  color: const Color(0xFF1FBF9A),
                  size: 40,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Recherche en cours...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nous recherchons les meilleurs $providerLabel\ndisponibles près de vous',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: const Color(0xFF667085),
              height: 1.5,
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
                            '${provider['price']} DH',
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
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
                  '${_minPrice.round()} DH',
                  '${_maxPrice.round()} DH',
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
                    '${_minPrice.round()} DH',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF667085),
                    ),
                  ),
                  Text(
                    '${_maxPrice.round()} DH',
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
