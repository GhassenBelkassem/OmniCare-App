import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/omni_theme.dart';
import 'data/professional_access_request_api.dart';

class ProfessionalAccessRequestScreen extends StatefulWidget {
  const ProfessionalAccessRequestScreen({super.key, required this.api});

  final ProfessionalAccessRequestApi api;

  @override
  State<ProfessionalAccessRequestScreen> createState() =>
      _ProfessionalAccessRequestScreenState();
}

class _ProfessionalAccessRequestScreenState
    extends State<ProfessionalAccessRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profession = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController(text: '+216');
  final _identifier = TextEditingController();
  final _specialty = TextEditingController();
  final _governorate = TextEditingController();
  final _organization = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _profession,
      _firstName,
      _lastName,
      _email,
      _phone,
      _identifier,
      _specialty,
      _governorate,
      _organization,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.submit({
        'profession': _profession.text.trim(),
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'professionalIdentifier': _identifier.text.trim(),
        'specialty': _optional(_specialty),
        'governorate': _optional(_governorate),
        'organization': _optional(_organization),
      });
      if (mounted) setState(() => _submitted = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Champ requis' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        title: const Text('Accès professionnel'),
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.pageHorizontal,
              OmniSpacing.lg,
              OmniSpacing.pageHorizontal,
              OmniSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _submitted ? _success() : _form(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _success() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: OmniColors.mintSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 34,
            color: OmniColors.deepTeal,
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Demande envoyée',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: OmniColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Notre équipe vérifiera vos informations.\n\nVous serez informé lorsque votre accès professionnel pourra être activé.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          color: OmniColors.textSecondary,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 32),
      ElevatedButton(
        onPressed: () => Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (_) => false),
        child: const Text('Retour à la connexion'),
      ),
    ],
  );

  Widget _form() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Demander à rejoindre OmniCare',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: OmniColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'L’accès professionnel OmniCare est réservé aux professionnels vérifiés.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            color: OmniColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        _field(
          _profession,
          'Profession',
          icon: Icons.medical_services_outlined,
          validator: _required,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final firstName = _field(
              _firstName,
              'Prénom',
              icon: Icons.person_outline_rounded,
              validator: _required,
            );
            final lastName = _field(
              _lastName,
              'Nom',
              icon: Icons.badge_outlined,
              validator: _required,
            );
            if (constraints.maxWidth < 420) {
              return Column(children: [firstName, lastName]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: firstName),
                const SizedBox(width: OmniSpacing.md),
                Expanded(child: lastName),
              ],
            );
          },
        ),
        _field(
          _email,
          'E-mail professionnel',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) =>
              _required(value) ??
              (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())
                  ? 'E-mail invalide'
                  : null),
        ),
        _field(
          _phone,
          'Téléphone (+216)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) =>
              RegExp(r'^\+216[0-9]{8}$').hasMatch(value?.trim() ?? '')
              ? null
              : 'Format +216XXXXXXXX requis',
        ),
        _field(
          _identifier,
          'Licence ou identifiant professionnel',
          icon: Icons.verified_user_outlined,
          validator: _required,
        ),
        _field(
          _specialty,
          'Spécialité (facultatif)',
          icon: Icons.health_and_safety_outlined,
        ),
        _field(
          _governorate,
          'Gouvernorat (facultatif)',
          icon: Icons.location_on_outlined,
        ),
        _field(
          _organization,
          'Établissement / cabinet (facultatif)',
          icon: Icons.apartment_outlined,
        ),
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: OmniSpacing.md),
            padding: const EdgeInsets.all(OmniSpacing.md),
            decoration: BoxDecoration(
              color: OmniColors.errorSoft,
              borderRadius: BorderRadius.circular(OmniRadii.field),
            ),
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Envoyer ma demande'),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: OmniColors.textSecondary),
      ),
    ),
  );
}
