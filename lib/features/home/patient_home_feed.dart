import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'add_family_member_screen.dart';
import 'patient_care_destinations.dart';

const _ink = Color(0xFF111827);
const _muted = Color(0xFF667085);
const _teal = Color(0xFF087A65);
const _mint = Color(0xFF1FBF9A);
const _darkTeal = Color(0xFF073E3C);
const _paleTeal = Color(0xFFE8F8F3);
const _line = Color(0xFFE1E7E5);

class PatientHomeFeed extends StatefulWidget {
  const PatientHomeFeed({
    super.key,
    required this.displayName,
    this.onOpenHealth,
    this.onOpenMedicalRecord,
    this.onOpenProfile,
  });

  final String displayName;
  final VoidCallback? onOpenHealth;
  final VoidCallback? onOpenMedicalRecord;
  final VoidCallback? onOpenProfile;

  @override
  State<PatientHomeFeed> createState() => _PatientHomeFeedState();
}

class _PatientHomeFeedState extends State<PatientHomeFeed> {
  final PageController _highlightController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  int _highlightIndex = 0;
  bool _searchOpen = false;

  static const _highlights = <_HealthHighlight>[
    _HealthHighlight(
      category: 'Conseil santé',
      minutes: '3 min',
      title: '30 minutes de marche font déjà la différence',
      description:
          'Une routine douce et régulière aide votre cœur, votre sommeil et votre énergie.',
      icon: Icons.monitor_heart_outlined,
    ),
    _HealthHighlight(
      category: 'Bien-être',
      minutes: '4 min',
      title: 'Une pause hydratation au bon moment',
      description:
          'Des gestes simples au fil de la journée contribuent à votre équilibre général.',
      icon: Icons.water_drop_outlined,
    ),
    _HealthHighlight(
      category: 'Sommeil',
      minutes: '5 min',
      title: 'Préparez une soirée vraiment reposante',
      description:
          'Un rythme régulier et un environnement calme favorisent un sommeil de qualité.',
      icon: Icons.bedtime_outlined,
    ),
  ];

  @override
  void dispose() {
    _highlightController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _searchOpen ? _buildSearchOverlay() : _buildFeed(),
        ),
        if (!_searchOpen)
          Positioned(right: 18, bottom: 18, child: _buildAssistantButton()),
      ],
    );
  }

  Widget _buildFeed() {
    return SingleChildScrollView(
      key: const ValueKey('patient-home-feed'),
      padding: const EdgeInsets.only(bottom: 108),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGreeting(),
                const SizedBox(height: 32),
                _buildHighlights(),
                const SizedBox(height: 28),
                _buildOmniBandCard(),
                const SizedBox(height: 28),
                _buildCareSection(),
                const SizedBox(height: 32),
                _buildCommunitySection(),
                const SizedBox(height: 28),
                _buildReferralCard(),
                const SizedBox(height: 28),
                _buildOverviewCard(),
                const SizedBox(height: 24),
                _buildPrivacyStrip(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final rawName = widget.displayName.trim();
    final firstName = rawName.isEmpty || rawName.toLowerCase() == 'user'
        ? 'Sarah'
        : rawName.split(RegExp(r'\s+')).first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 355;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFFE177), Color(0xFFC78B13)],
                    ).createShader(bounds),
                    child: Text(
                      'Bonjour $firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(
                        size: compact ? 20 : 23,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prenez soin de vous, un geste à la fois.',
                    style: _text(
                      size: 11.5,
                      weight: FontWeight.w500,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: 'Rechercher dans OmniCare',
              child: Material(
                color: Colors.white,
                shape: CircleBorder(side: BorderSide(color: _line)),
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openSearch,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.search_rounded,
                      color: Color(0xFF006B5B),
                      size: 21,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHighlights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POUR VOUS',
          style: _text(
            size: 12.5,
            weight: FontWeight.w800,
            color: _teal,
            letterSpacing: 2.1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Votre rendez-vous santé',
                style: _text(
                  size: 25,
                  weight: FontWeight.w800,
                  color: _ink,
                  height: 1.15,
                ),
              ),
            ),
            Text(
              '${_highlightIndex + 1}/${_highlights.length}',
              style: _text(
                size: 14,
                weight: FontWeight.w700,
                color: const Color(0xFF98A2B3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 365,
          child: PageView.builder(
            controller: _highlightController,
            itemCount: _highlights.length,
            onPageChanged: (value) => setState(() => _highlightIndex = value),
            itemBuilder: (context, index) =>
                _buildHighlightCard(_highlights[index]),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_highlights.length, (index) {
            final active = index == _highlightIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 28 : 9,
              height: 9,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: active ? _teal : const Color(0xFFCEDAD7),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHighlightCard(_HealthHighlight highlight) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173B37).withValues(alpha: 0.09),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 188,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/health-carousel.png',
                  fit: BoxFit.cover,
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: _whitePill(
                    icon: highlight.icon,
                    label: highlight.category,
                    color: const Color(0xFF006B5B),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF073E3C).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          highlight.minutes,
                          style: _text(
                            size: 12,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 78,
                  child: _carouselArrow(Icons.arrow_back_rounded, -1),
                ),
                Positioned(
                  right: 14,
                  top: 78,
                  child: _carouselArrow(Icons.arrow_forward_rounded, 1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 19, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  highlight.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    size: 20,
                    weight: FontWeight.w800,
                    color: _ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  highlight.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    size: 14,
                    weight: FontWeight.w500,
                    color: _muted,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carouselArrow(IconData icon, int delta) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          final next =
              (_highlightIndex + delta + _highlights.length) %
              _highlights.length;
          _highlightController.animateToPage(
            next,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        },
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: _teal),
        ),
      ),
    );
  }

  Widget _buildOmniBandCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _darkTeal,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _darkTeal.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 215,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.white),
                Image.asset(
                  'assets/images/omnicare-band.png',
                  fit: BoxFit.contain,
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF073E3C)],
                      ),
                    ),
                    child: SizedBox(height: 45, width: double.infinity),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LA PROCHAINE EXPÉRIENCE OMNICARE',
                  style: _text(
                    size: 11.5,
                    weight: FontWeight.w800,
                    color: const Color(0xFF74E2CD),
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'OmniBand, votre santé en mouvement',
                  style: _text(
                    size: 27,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    style: _text(
                      size: 14,
                      weight: FontWeight.w500,
                      color: const Color(0xFFD0DEDC),
                      height: 1.55,
                    ),
                    children: const [
                      TextSpan(
                        text:
                            'Complétez 5 étapes avec OmniCare pour recevoir votre bracelet connecté : vos rendez-vous validés, plus jusqu’à ',
                      ),
                      TextSpan(
                        text: '2 étapes',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' gagnées grâce à vos amis. Vos constantes rejoignent Ma santé pour mieux suivre votre évolution et, avec votre accord, éclairer votre médecin.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.event_available_outlined,
                            color: Color(0xFF74E2CD),
                            size: 21,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Votre parcours vers OmniBand',
                              style: _text(
                                size: 12.5,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '0 / 5',
                            style: _text(
                              size: 13,
                              weight: FontWeight.w800,
                              color: const Color(0xFFFFDD66),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Expanded(
                            child: Container(
                              height: 7,
                              margin: EdgeInsets.only(
                                right: index == 4 ? 0 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF7FA6A1,
                                ).withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Jusqu’à 2 étapes peuvent être obtenues en invitant 2 amis.',
                          style: _text(
                            size: 10.5,
                            weight: FontWeight.w600,
                            color: const Color(0xFFAAC0BD),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _darkFeatureChip(
                        Icons.monitor_heart_outlined,
                        'Suivi santé continu',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _darkFeatureChip(
                        Icons.verified_user_outlined,
                        'Partage sous contrôle',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkFeatureChip(IconData icon, String text) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF74E2CD)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: _text(
                size: 10.5,
                weight: FontWeight.w700,
                color: const Color(0xFFD9E6E4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareSection() {
    const services = patientCareDestinations;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconBox(Icons.medical_services_outlined, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demander des soins',
                        style: _text(
                          size: 21,
                          weight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choisissez le service adapté à votre besoin',
                        style: _text(
                          size: 13,
                          weight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          Padding(
            padding: const EdgeInsets.all(14),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 190,
              ),
              itemCount: services.length,
              itemBuilder: (context, index) => _buildCareTile(services[index]),
            ),
          ),
          const Divider(height: 1, color: _line),
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('my-requests-entry'),
              onTap: () => _navigateNamed('/m05/requests'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 16, 15),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, color: _teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mes demandes',
                            style: _text(
                              size: 14,
                              weight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Suivre mes demandes de soins',
                            style: _text(
                              size: 12,
                              weight: FontWeight.w500,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareTile(PatientCareDestination service) {
    return Material(
      color: const Color(0xFFFCFDFD),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openCare(service),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(service.icon, size: 48),
              const SizedBox(height: 13),
              Text(
                service.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _text(
                  size: 14,
                  weight: FontWeight.w800,
                  color: const Color(0xFF202A3B),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Text(
                  service.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: _muted,
                    height: 1.4,
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF98A2B3),
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommunitySection() {
    const stats = <(String, String)>[
      ('350', 'Médecins'),
      ('100', 'Kinés'),
      ('150', 'Infirmiers'),
      ('10', 'Cliniques'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vous êtes bien entourée',
                style: _text(
                  size: 26,
                  weight: FontWeight.w800,
                  color: const Color(0xFF151515),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Un réseau de santé vérifié, disponible quand vous en avez besoin.',
                style: _text(
                  size: 13,
                  weight: FontWeight.w500,
                  color: const Color(0xFF71717A),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Row(
                  children: [
                    _iconBox(Icons.people_alt_outlined, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plus de 1 000 patients',
                            style: _text(
                              size: 20,
                              weight: FontWeight.w800,
                              color: const Color(0xFF1B1B1F),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'font déjà confiance à OmniCare',
                            style: _text(
                              size: 13,
                              weight: FontWeight.w500,
                              color: const Color(0xFF71717A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.verified_outlined,
                      size: 27,
                      color: Color(0xFF22C55E),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20, color: _line),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 6,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(stats.length, (index) {
                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: index == 0
                              ? null
                              : const Border(left: BorderSide(color: _line)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              stats[index].$1,
                              style: _text(
                                size: 22,
                                weight: FontWeight.w800,
                                color: _mint,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              stats[index].$2,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              style: _text(
                                size: 10.5,
                                weight: FontWeight.w600,
                                color: const Color(0xFF8A8A92),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const Divider(height: 1, color: _line),
              _communityInfoRow(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF15933B),
                iconBackground: const Color(0xFFECF8ED),
                title: 'Votre espace est sécurisé',
                description:
                    'Vos données restent privées et le partage se fait avec votre autorisation.',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECF8ED),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Protégé',
                    style: _text(
                      size: 11,
                      weight: FontWeight.w700,
                      color: const Color(0xFF15933B),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20, color: _line),
              _communityInfoRow(
                icon: Icons.headset_mic_outlined,
                iconColor: const Color(0xFF0878F9),
                iconBackground: const Color(0xFFEAF2FF),
                title: 'Service client 24 h/24, 7 j/7',
                description: 'Une équipe vous accompagne à tout moment.',
                trailing: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _communityInfoRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String description,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _text(
                    size: 14,
                    weight: FontWeight.w800,
                    color: const Color(0xFF232326),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: _text(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: const Color(0xFF71717A),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _buildReferralCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_darkTeal, Color(0xFF07554E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _darkTeal.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFF74E2CD),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INVITEZ VOS PROCHES',
                      style: _text(
                        size: 11.5,
                        weight: FontWeight.w800,
                        color: const Color(0xFF74E2CD),
                        letterSpacing: 1.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Avancez plus vite vers votre OmniBand',
                      style: _text(
                        size: 24,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              style: _text(
                size: 14,
                weight: FontWeight.w500,
                color: const Color(0xFFD0DEDC),
                height: 1.55,
              ),
              children: const [
                TextSpan(
                  text:
                      'Chaque ami dont le compte est approuvé, créé et connecté vous fait gagner ',
                ),
                TextSpan(
                  text: '1 étape. ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                TextSpan(text: 'Vous pouvez gagner au maximum '),
                TextSpan(
                  text: '2 étapes',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFDD66),
                  ),
                ),
                TextSpan(text: ' avec 2 amis.'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD95C).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFFFD95C).withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.group_add_outlined,
                      color: Color(0xFFFFDD66),
                      size: 23,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bonus amis validés',
                        style: _text(
                          size: 12,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '0 / 2',
                      style: _text(
                        size: 13,
                        weight: FontWeight.w800,
                        color: const Color(0xFFFFDD66),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(child: _progressSegment()),
                    const SizedBox(width: 8),
                    Expanded(child: _progressSegment()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMMENT ÇA MARCHE ?',
                  style: _text(
                    size: 11,
                    weight: FontWeight.w800,
                    color: const Color(0xFFAAC0BD),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                _referralStep(
                  1,
                  Icons.send_outlined,
                  'Envoyez le lien',
                  'Partagez votre invitation avec un ami.',
                ),
                const SizedBox(height: 13),
                _referralStep(
                  2,
                  Icons.person_add_alt_1_outlined,
                  'Donnez votre code',
                  'Votre ami le saisit pendant son inscription.',
                ),
                const SizedBox(height: 13),
                _referralStep(
                  3,
                  Icons.login_rounded,
                  'Gagnez une étape',
                  'Après validation du compte et première connexion.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOTRE CODE D’INVITATION',
                  style: _text(
                    size: 11,
                    weight: FontWeight.w800,
                    color: _muted,
                    letterSpacing: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: _paleTeal,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'OMNI-SARAH',
                          style: _text(
                            size: 16,
                            weight: FontWeight.w800,
                            color: _teal,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _copyButton(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF74E2CD),
                foregroundColor: _darkTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _shareInvitation,
              icon: const Icon(Icons.link_rounded, size: 21),
              label: Text(
                'Envoyer mon lien d’invitation',
                style: _text(
                  size: 13.5,
                  weight: FontWeight.w800,
                  color: _darkTeal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressSegment() {
    return Container(
      height: 7,
      decoration: BoxDecoration(
        color: const Color(0xFF7FA6A1).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  Widget _referralStep(
    int number,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2A6963),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: const Color(0xFF74E2CD), size: 20),
            ),
            Positioned(
              right: -5,
              top: -7,
              child: Container(
                width: 21,
                height: 21,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFDD66),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: _text(
                      size: 9.5,
                      weight: FontWeight.w800,
                      color: _darkTeal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _text(
                  size: 13,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: _text(
                  size: 10.5,
                  weight: FontWeight.w500,
                  color: const Color(0xFFAAC0BD),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _copyButton() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _copyText('OMNI-SARAH', 'Code copié'),
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.copy_rounded, color: _teal, size: 21),
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconBox(Icons.format_list_bulleted_rounded, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Votre espace OmniCare',
                        style: _text(
                          size: 21,
                          weight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Vos soins, votre dossier et vos proches dans une seule application',
                        style: _text(
                          size: 13,
                          weight: FontWeight.w500,
                          color: _muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          _overviewRow(
            Icons.medical_services_outlined,
            'Soins',
            'Demandez et organisez vos soins depuis un point d’entrée unique.',
            () => Navigator.pushNamed(context, '/provider-selection'),
          ),
          const Divider(height: 1, color: _line),
          _overviewRow(
            Icons.description_outlined,
            'Dossier médical',
            'Retrouvez vos informations et documents de santé.',
            () => _runAndClose(widget.onOpenMedicalRecord),
          ),
          const Divider(height: 1, color: _line),
          _overviewRow(
            Icons.people_outline_rounded,
            'Famille',
            'Accompagnez vos proches tout en gardant leurs dossiers séparés.',
            _openFamily,
          ),
        ],
      ),
    );
  }

  Widget _overviewRow(
    IconData icon,
    String title,
    String description,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          child: Row(
            children: [
              _iconBox(icon, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _text(
                        size: 15,
                        weight: FontWeight.w800,
                        color: const Color(0xFF202A3B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: _text(
                        size: 12,
                        weight: FontWeight.w500,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyStrip() {
    return Material(
      color: const Color(0xFFEAF9F5),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _showLanguageSheet,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFA8EAD9)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, color: _teal, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vos informations restent privées et accessibles uniquement selon les autorisations que vous accordez.',
                      style: _text(
                        size: 13,
                        weight: FontWeight.w600,
                        color: _teal,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Français · العربية · English',
                      style: _text(
                        size: 12,
                        weight: FontWeight.w600,
                        color: _muted,
                      ),
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

  Widget _buildSearchOverlay() {
    final query = _searchController.text.trim().toLowerCase();
    final allItems = _searchItems();
    final visibleItems = query.isEmpty
        ? allItems.where((item) => item.suggested).toList()
        : allItems
              .where(
                (item) => '${item.title} ${item.subtitle} ${item.keywords}'
                    .toLowerCase()
                    .contains(query),
              )
              .toList();
    final sections = query.isEmpty
        ? const ['Suggestions']
        : const ['Actions', 'Dans OmniCare', 'Aide'];

    return ColoredBox(
      key: const ValueKey('patient-home-search'),
      color: const Color(0xFFF6F7F8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 16, 16, 15),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Fermer la recherche',
                          onPressed: _closeSearch,
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF475467),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: (_) => setState(() {}),
                            style: _text(
                              size: 15,
                              weight: FontWeight.w600,
                              color: _ink,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Que souhaitez-vous faire ?',
                              hintStyle: _text(
                                size: 14,
                                weight: FontWeight.w600,
                                color: const Color(0xFF98A2B3),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: _muted,
                              ),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: _teal,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: _teal,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Recherche de navigation et d’assistance — aucun diagnostic médical.',
                        style: _text(
                          size: 11.5,
                          weight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                  children: [
                    if (visibleItems.isEmpty)
                      _buildEmptySearch(query)
                    else
                      for (final section in sections)
                        if (visibleItems.any(
                          (item) =>
                              (query.isEmpty ? 'Suggestions' : item.section) ==
                              section,
                        )) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                            child: Text(
                              section,
                              style: _text(
                                size: 16,
                                weight: FontWeight.w800,
                                color: const Color(0xFF344054),
                              ),
                            ),
                          ),
                          _searchResultsCard(
                            visibleItems
                                .where(
                                  (item) =>
                                      (query.isEmpty
                                          ? 'Suggestions'
                                          : item.section) ==
                                      section,
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchResultsCard(List<_SearchItem> items) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6DCE3)),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              Material(
                color: Colors.white,
                child: InkWell(
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        _iconBox(item.icon, size: 48),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: _text(
                                  size: 15,
                                  weight: FontWeight.w800,
                                  color: const Color(0xFF202A3B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: _text(
                                  size: 12,
                                  weight: FontWeight.w500,
                                  color: _muted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF98A2B3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index != items.length - 1)
                const Divider(height: 1, color: _line),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildEmptySearch(String query) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Icon(
            Icons.manage_search_rounded,
            size: 54,
            color: Color(0xFF98A2B3),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun raccourci trouvé',
            style: _text(size: 18, weight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 7),
          Text(
            'Essayez “soins”, “dossier”, “famille” ou “aide”.',
            textAlign: TextAlign.center,
            style: _text(size: 13, weight: FontWeight.w500, color: _muted),
          ),
        ],
      ),
    );
  }

  List<_SearchItem> _searchItems() => [
    _SearchItem(
      'Actions',
      'Demander des soins',
      'Choisir le service adapté à votre besoin.',
      Icons.medical_services_outlined,
      'médecin infirmier kiné clinique rendez-vous',
      true,
      () => _navigateNamed('/provider-selection'),
    ),
    _SearchItem(
      'Dans OmniCare',
      'Ouvrir mon dossier médical',
      'Accéder au Passeport médical.',
      Icons.description_outlined,
      'documents passeport analyses ordonnance',
      true,
      () => _runAndClose(widget.onOpenMedicalRecord),
    ),
    _SearchItem(
      'Actions',
      'Ajouter un membre de la famille',
      'Créer un profil séparé pour un proche.',
      Icons.person_add_alt_1_outlined,
      'proche enfant parent famille',
      true,
      _openFamily,
    ),
    _SearchItem(
      'Dans OmniCare',
      'Voir mes notifications',
      'Consulter les demandes, rappels et messages.',
      Icons.notifications_none_rounded,
      'messages alertes rappels',
      true,
      () => _navigateNamed('/notifications'),
    ),
    _SearchItem(
      'Actions',
      'Demander un médecin',
      'Démarrer une demande de consultation.',
      Icons.medical_services_outlined,
      'docteur domicile rendez-vous',
      false,
      () => _openCare(patientCareDestination(PatientCareType.doctor)),
    ),
    _SearchItem(
      'Actions',
      'Demander un infirmier',
      'Organiser des soins infirmiers à domicile.',
      Icons.vaccines_outlined,
      'pansement injection domicile',
      false,
      () => _openCare(patientCareDestination(PatientCareType.nurse)),
    ),
    _SearchItem(
      'Dans OmniCare',
      'Consulter Ma santé',
      'Retrouver vos informations essentielles.',
      Icons.favorite_border_rounded,
      'constantes santé profil médical',
      false,
      () => _runAndClose(widget.onOpenHealth),
    ),
    _SearchItem(
      'Dans OmniCare',
      'Ouvrir mon profil',
      'Gérer votre compte et vos préférences.',
      Icons.person_outline_rounded,
      'compte langue préférences',
      false,
      () => _runAndClose(widget.onOpenProfile),
    ),
    _SearchItem(
      'Aide',
      'Contacter l’assistance',
      'Obtenir de l’aide pour utiliser OmniCare.',
      Icons.headset_mic_outlined,
      'support service client problème',
      false,
      _showAssistantSheet,
    ),
    _SearchItem(
      'Aide',
      'Confidentialité et partage',
      'Comprendre vos autorisations de données.',
      Icons.verified_user_outlined,
      'privé sécurité autorisation données',
      false,
      _showPrivacyMessage,
    ),
  ];

  Widget _buildAssistantButton() {
    return Semantics(
      button: true,
      label: 'Ouvrir l’assistant OmniCare',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _showAssistantSheet,
          child: SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(
                  child: Icon(Icons.smart_toy_outlined, color: _teal, size: 28),
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: _mint,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
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

  Widget _iconBox(IconData icon, {double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _paleTeal,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: _teal, size: size * 0.47),
    );
  }

  Widget _whitePill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Text(
            label,
            style: _text(size: 12, weight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocus.requestFocus(),
    );
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    _searchController.clear();
    setState(() => _searchOpen = false);
  }

  void _openCare(PatientCareDestination destination) {
    if (destination.isClinic) {
      _navigateNamed(destination.route);
      return;
    }
    _closeSearchIfNeeded();
    Navigator.pushNamed(
      context,
      '/emergency-step0',
      arguments: {'providerType': destination.type.name},
    );
  }

  void _navigateNamed(String route) {
    _closeSearchIfNeeded();
    Navigator.pushNamed(context, route);
  }

  void _openFamily() {
    _closeSearchIfNeeded();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFamilyMemberScreen()),
    );
  }

  void _runAndClose(VoidCallback? callback) {
    _closeSearchIfNeeded();
    callback?.call();
  }

  void _closeSearchIfNeeded() {
    if (!_searchOpen) return;
    _searchFocus.unfocus();
    _searchController.clear();
    setState(() => _searchOpen = false);
  }

  void _copyText(String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _shareInvitation() {
    _copyText(
      'https://omnicare.tn/invitation/OMNI-SARAH',
      'Lien d’invitation copié — vous pouvez maintenant le partager.',
    );
  }

  void _showPrivacyMessage() {
    _closeSearchIfNeeded();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_outlined, size: 38, color: _teal),
            const SizedBox(height: 14),
            Text(
              'Vos données, vos autorisations',
              style: _text(size: 19, weight: FontWeight.w800, color: _ink),
            ),
            const SizedBox(height: 9),
            Text(
              'Vos informations de santé restent privées. Un partage n’est effectué qu’avec les autorisations que vous accordez.',
              textAlign: TextAlign.center,
              style: _text(
                size: 13,
                weight: FontWeight.w500,
                color: _muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Langue de l’application',
              style: _text(size: 19, weight: FontWeight.w800, color: _ink),
            ),
            const SizedBox(height: 14),
            for (final language in ['Français', 'العربية', 'English'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  language,
                  style: _text(size: 15, weight: FontWeight.w700, color: _ink),
                ),
                trailing: language == 'Français'
                    ? const Icon(Icons.check_circle_rounded, color: _teal)
                    : null,
                onTap: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }

  void _showAssistantSheet() {
    _closeSearchIfNeeded();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _iconBox(Icons.smart_toy_outlined, size: 48),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assistant OmniCare',
                          style: _text(
                            size: 18,
                            weight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        Text(
                          'En ligne · aide à la navigation',
                          style: _text(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: _teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: _paleTeal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Bonjour ! Je peux vous aider à trouver un service ou une rubrique OmniCare. Je ne fournis pas de diagnostic médical.',
                  style: _text(
                    size: 13,
                    weight: FontWeight.w500,
                    color: const Color(0xFF175B50),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openSearch();
                },
                icon: const Icon(Icons.search_rounded),
                label: const Text('Rechercher dans OmniCare'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/provider-selection');
                },
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text('Demander des soins'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _text({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

class _HealthHighlight {
  const _HealthHighlight({
    required this.category,
    required this.minutes,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String category;
  final String minutes;
  final String title;
  final String description;
  final IconData icon;
}

class _SearchItem {
  const _SearchItem(
    this.section,
    this.title,
    this.subtitle,
    this.icon,
    this.keywords,
    this.suggested,
    this.onTap,
  );

  final String section;
  final String title;
  final String subtitle;
  final IconData icon;
  final String keywords;
  final bool suggested;
  final VoidCallback onTap;
}
