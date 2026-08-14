import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClinicRequestScreen extends StatefulWidget {
  const ClinicRequestScreen({super.key});

  @override
  State<ClinicRequestScreen> createState() => _ClinicRequestScreenState();
}

class _ClinicRequestScreenState extends State<ClinicRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  String? _clinic;
  String? _service;
  String _timing = 'Premier créneau disponible';
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1D2939)),
        ),
        title: Text(
          'Demande à une clinique',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8F3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.local_hospital_outlined,
                                    color: Color(0xFF087A65),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Organisez votre prise en charge',
                                        style: _style(
                                          17,
                                          FontWeight.w800,
                                          const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'Choisissez une clinique et le service souhaité. L’équipe vous recontactera pour confirmer.',
                                        style: _style(
                                          12.5,
                                          FontWeight.w500,
                                          const Color(0xFF526A66),
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _label('Clinique'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _clinic,
                            decoration: _inputDecoration(
                              'Sélectionnez une clinique',
                              Icons.local_hospital_outlined,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Clinique Les Oliviers',
                                child: Text('Clinique Les Oliviers'),
                              ),
                              DropdownMenuItem(
                                value: 'Clinique La Marsa',
                                child: Text('Clinique La Marsa'),
                              ),
                              DropdownMenuItem(
                                value: 'Centre Médical Carthage',
                                child: Text('Centre Médical Carthage'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _clinic = value),
                            validator: (value) => value == null
                                ? 'Veuillez sélectionner une clinique'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          _label('Service demandé'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _service,
                            decoration: _inputDecoration(
                              'Sélectionnez un service',
                              Icons.medical_services_outlined,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Consultation spécialisée',
                                child: Text('Consultation spécialisée'),
                              ),
                              DropdownMenuItem(
                                value: 'Imagerie médicale',
                                child: Text('Imagerie médicale'),
                              ),
                              DropdownMenuItem(
                                value: 'Analyses',
                                child: Text('Analyses'),
                              ),
                              DropdownMenuItem(
                                value: 'Hospitalisation',
                                child: Text('Hospitalisation'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _service = value),
                            validator: (value) => value == null
                                ? 'Veuillez sélectionner un service'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          _label('Préférence de rendez-vous'),
                          const SizedBox(height: 8),
                          RadioGroup<String>(
                            groupValue: _timing,
                            onChanged: (value) =>
                                setState(() => _timing = value!),
                            child: Column(
                              children: [
                                for (final timing in const [
                                  'Premier créneau disponible',
                                  'Cette semaine',
                                  'Je souhaite être rappelé(e)',
                                ])
                                  RadioListTile<String>(
                                    value: timing,
                                    title: Text(
                                      timing,
                                      style: _style(
                                        13,
                                        FontWeight.w600,
                                        const Color(0xFF344054),
                                      ),
                                    ),
                                    activeColor: const Color(0xFF087A65),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          _label('Informations complémentaires (facultatif)'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _detailsController,
                            maxLines: 4,
                            maxLength: 500,
                            decoration: _inputDecoration(
                              'Précisez votre demande sans inclure de données urgentes.',
                              Icons.notes_rounded,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: Color(0xFF667085),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cette demande ne remplace pas les services d’urgence. En cas d’urgence vitale, contactez les services compétents.',
                                  style: _style(
                                    11.5,
                                    FontWeight.w500,
                                    const Color(0xFF667085),
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE1E7E5))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF087A65),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Envoyer la demande',
                            style: _style(14, FontWeight.w800, Colors.white),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() => _submitting = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF1FBF9A),
          size: 45,
        ),
        title: Text(
          'Demande envoyée',
          style: _style(19, FontWeight.w800, const Color(0xFF111827)),
        ),
        content: Text(
          '$_clinic vous recontactera pour confirmer votre demande en $_service.',
          textAlign: TextAlign.center,
          style: _style(
            13,
            FontWeight.w500,
            const Color(0xFF667085),
            height: 1.45,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: _style(13, FontWeight.w800, const Color(0xFF344054)));

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: _style(12.5, FontWeight.w500, const Color(0xFF98A2B3)),
      prefixIcon: Icon(icon, color: const Color(0xFF087A65), size: 21),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFD8E0DE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFD8E0DE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF087A65), width: 1.5),
      ),
    );
  }

  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color, {
    double? height,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }
}
