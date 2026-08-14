import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/family_models.dart';
import '../../providers/family_provider.dart';

class AddFamilyMemberScreen extends StatefulWidget {
  const AddFamilyMemberScreen({super.key, this.member});

  final FamilyMember? member;

  bool get isEditing => member != null;

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  static const _teal = Color(0xFF1FBF9A);
  static const _ink = Color(0xFF1A202C);
  static const _muted = Color(0xFF667085);
  static const _line = Color(0xFFE2E8F0);

  final _formKey = GlobalKey<FormState>();
  final _dateFieldKey = GlobalKey<FormFieldState<DateTime>>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  DateTime? _dateOfBirth;
  String? _gender;
  String? _relationship;
  bool _submitting = false;
  bool _validationEnabled = false;
  Map<String, String> _serverErrors = const {};

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    _firstNameController = TextEditingController(text: member?.firstName ?? '');
    _lastNameController = TextEditingController(text: member?.lastName ?? '');
    _dateOfBirth = member?.dateOfBirth;
    _gender = member?.gender;
    _relationship = member?.relationship;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (_submitting) return;
    final today = DateTime.now();
    final latest = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(today.year - 10),
      firstDate: DateTime(1900),
      lastDate: latest,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _dateOfBirth = selected;
    });
    _clearServerError('dateOfBirth');
    _dateFieldKey.currentState?.didChange(selected);
    if (_validationEnabled) {
      _dateFieldKey.currentState?.validate();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (!_validationEnabled) {
      setState(() => _validationEnabled = true);
    }
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _submitting = true;
      _serverErrors = const {};
    });
    final provider = context.read<FamilyProvider>();
    provider.clearMutationError();

    try {
      final member = widget.member;
      if (member == null) {
        await provider.addFamilyMember(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          dateOfBirth: _dateOfBirth!,
          gender: _gender!,
          relationship: _relationship!,
        );
      } else {
        await provider.updateFamilyMember(
          id: member.id,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          dateOfBirth: _dateOfBirth!,
          gender: _gender!,
          relationship: _relationship!,
          photoUrl: member.photoUrl,
        );
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Membre mis à jour.'
                : 'Membre ajouté à votre famille.',
          ),
          backgroundColor: _teal,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverErrors = provider.fieldErrors;
        _submitting = false;
      });
      _formKey.currentState?.validate();
    }
  }

  void _clearServerError(String field) {
    if (!_serverErrors.containsKey(field)) return;
    setState(() {
      _serverErrors = Map.of(_serverErrors)..remove(field);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyProvider>();
    final disabled = _submitting || provider.isSaving;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: disabled ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          widget.isEditing ? 'Modifier le membre' : 'Ajouter un membre',
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, viewport) {
            final horizontalPadding = viewport.maxWidth > 720
                ? ((viewport.maxWidth - 720) / 2) + 24
                : 20.0;
            return Form(
              key: _formKey,
              autovalidateMode: _validationEnabled
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  20,
                  horizontalPadding,
                  32,
                ),
                children: [
                  _AvatarPreview(
                    name:
                        '${_firstNameController.text} ${_lastNameController.text}',
                    photoUrl: widget.member?.photoUrl,
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    title: 'Informations personnelles',
                    subtitle:
                        'Ces informations identifient ce membre du foyer.',
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final firstName = _buildNameField(
                        controller: _firstNameController,
                        label: 'Prénom',
                        validationLabel: 'prénom',
                        icon: Icons.person_outline_rounded,
                        field: 'firstName',
                        enabled: !disabled,
                        textInputAction: TextInputAction.next,
                      );
                      final lastName = _buildNameField(
                        controller: _lastNameController,
                        label: 'Nom',
                        validationLabel: 'nom',
                        icon: Icons.badge_outlined,
                        field: 'lastName',
                        enabled: !disabled,
                        textInputAction: TextInputAction.done,
                      );
                      if (constraints.maxWidth < 520) {
                        return Column(
                          children: [
                            firstName,
                            const SizedBox(height: 12),
                            lastName,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: firstName),
                          const SizedBox(width: 12),
                          Expanded(child: lastName),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FormField<DateTime>(
                    key: _dateFieldKey,
                    initialValue: _dateOfBirth,
                    autovalidateMode: _validationEnabled
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    validator: (_) {
                      if (_serverErrors['dateOfBirth'] != null) {
                        return _serverErrors['dateOfBirth'];
                      }
                      if (_dateOfBirth == null) {
                        return 'Sélectionnez la date de naissance.';
                      }
                      return null;
                    },
                    builder: (field) => InkWell(
                      onTap: disabled ? null : _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: _inputDecoration(
                          label: 'Date de naissance',
                          icon: Icons.calendar_today_outlined,
                          errorText: field.errorText,
                        ),
                        child: Text(
                          _dateOfBirth == null
                              ? 'Choisir une date'
                              : _displayDate(_dateOfBirth!),
                          style: TextStyle(
                            color: _dateOfBirth == null ? _muted : _ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    title: 'Genre',
                    subtitle: 'Utilisé uniquement pour l’identité du membre.',
                  ),
                  const SizedBox(height: 12),
                  FormField<String>(
                    initialValue: _gender,
                    autovalidateMode: _validationEnabled
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    validator: (_) {
                      return _serverErrors['gender'] ??
                          (_gender == null ? 'Sélectionnez le genre.' : null);
                    },
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'F', label: Text('Femme')),
                              ButtonSegment(value: 'M', label: Text('Homme')),
                              ButtonSegment(
                                value: 'autre',
                                label: Text('Autre'),
                              ),
                            ],
                            selected: _gender == null ? const {} : {_gender!},
                            emptySelectionAllowed: true,
                            onSelectionChanged: disabled
                                ? null
                                : (selection) {
                                    setState(() {
                                      _gender = selection.isEmpty
                                          ? null
                                          : selection.first;
                                    });
                                    _clearServerError('gender');
                                    field.didChange(_gender);
                                  },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.standard,
                              foregroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? Colors.white
                                    : _ink,
                              ),
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? _teal
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (field.errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    title: 'Lien familial',
                    subtitle:
                        'Choisissez la relation avec le titulaire du compte.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _relationship,
                    autovalidateMode: _validationEnabled
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    isExpanded: true,
                    decoration: _inputDecoration(
                      label: 'Relation',
                      icon: Icons.family_restroom_rounded,
                      errorText: _serverErrors['relationship'],
                    ),
                    items: FamilyRelationships.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(FamilyRelationships.frenchLabel(value)),
                          ),
                        )
                        .toList(growable: false),
                    validator: (value) =>
                        value == null ? 'Sélectionnez le lien familial.' : null,
                    onChanged: disabled
                        ? null
                        : (value) {
                            setState(() {
                              _relationship = value;
                            });
                            _clearServerError('relationship');
                          },
                  ),
                  if (provider.mutationError != null &&
                      _serverErrors.isEmpty) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: provider.mutationError!),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: disabled ? null : _submit,
                      icon: disabled
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              widget.isEditing
                                  ? Icons.save_outlined
                                  : Icons.person_add_alt_1_rounded,
                            ),
                      label: Text(
                        widget.isEditing
                            ? 'Enregistrer les modifications'
                            : 'Ajouter le membre',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNameField({
    required TextEditingController controller,
    required String label,
    required String validationLabel,
    required IconData icon,
    required String field,
    required bool enabled,
    required TextInputAction textInputAction,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autovalidateMode: _validationEnabled
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      textCapitalization: TextCapitalization.words,
      textInputAction: textInputAction,
      maxLength: 128,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        errorText: _serverErrors[field],
      ),
      validator: (value) => _requiredName(value, validationLabel),
      onChanged: (_) {
        _clearServerError(field);
        setState(() {});
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      prefixIcon: Icon(icon, size: 20),
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _teal, width: 2),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return Center(
      child: Container(
        width: 88,
        height: 88,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFD1FAE5),
          border: Border.all(color: const Color(0xFF1FBF9A), width: 2),
        ),
        child: url.isEmpty
            ? Center(
                child: Text(
                  initials.isEmpty ? '?' : initials,
                  style: const TextStyle(
                    color: Color(0xFF0F6F73),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const Icon(
                  Icons.person_rounded,
                  size: 38,
                  color: Color(0xFF0F6F73),
                ),
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1A202C),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFB42318), fontSize: 13),
      ),
    );
  }
}

String? _requiredName(String? value, String label) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Saisissez le $label.';
  if (text.length > 128) return 'Maximum 128 caractères.';
  return null;
}

String _displayDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
