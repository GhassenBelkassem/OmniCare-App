import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../../core/theme/omni_theme.dart';
import '../../../l10n/omni_localizations.dart';
import '../application/medical_documents_view_model.dart';
import '../data/document_file_picker.dart';
import '../data/medical_document_models.dart';
import '../data/medical_record_write_models.dart';
import 'medical_record_messages.dart';
import 'widgets/passport_card_status.dart';

/// « + » of the « Documents » tab (G2.1-A4): name, type, date and file of a
/// new document for the person on screen ([viewModel]'s subject). Local
/// checks first (15 Mo, PDF/JPG/PNG, name, date); the upload has one key, so
/// « Réessayer » sends the same request; a failure keeps everything typed.
class MedicalDocumentEditorScreen extends StatefulWidget {
  final String patientName;
  final MedicalDocumentsViewModel viewModel;

  /// The platform file picker (a fake in tests).
  final Future<DocumentFileSource?> Function() pickFile;

  const MedicalDocumentEditorScreen({
    super.key,
    required this.patientName,
    required this.viewModel,
    this.pickFile = pickDocumentFile,
  });

  @override
  State<MedicalDocumentEditorScreen> createState() =>
      _MedicalDocumentEditorScreenState();
}

/// The existing « Type de Document » choices and the server type each means.
const _documentTypes = {
  'Autre': MedicalDocumentType.other,
  'Analyse': MedicalDocumentType.labResult,
  'Ordonnance': MedicalDocumentType.prescription,
};

class _MedicalDocumentEditorScreenState
    extends State<MedicalDocumentEditorScreen> {
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _urlController = TextEditingController();
  final SaveAttempt _attempt = SaveAttempt();
  String _documentType = 'Autre';
  DocumentFileSource? _file;
  Map<String, ApiFieldErrorKind> _errors = const {};
  ApiFailure? _failure;
  bool _uploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  /// Something changed: the next « Enregistrer » is a new action (new key).
  void _edited() {
    _attempt.reset();
    if (_errors.isNotEmpty || _failure != null) {
      setState(() {
        _errors = const {};
        _failure = null;
      });
    }
  }

  Future<void> _pickFile() async {
    final file = await widget.pickFile();
    if (!mounted || file == null) return;
    setState(() {
      _file = file;
      _urlController.text = file.filename;
    });
    _edited();
  }

  void _clearForm() {
    setState(() {
      _nameController.clear();
      _dateController.clear();
      _urlController.clear();
      _file = null;
    });
    _edited();
  }

  Future<void> _save() async {
    if (_uploading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final errors = documentFormErrors(
      title: _nameController.text,
      dateText: _dateController.text,
      file: _file,
      now: DateTime.now(),
    );
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _failure = null;
      });
      return;
    }
    setState(() {
      _uploading = true;
      _failure = null;
    });
    final result = await widget.viewModel.upload(
      source: _file!,
      form: DocumentUploadForm(
        title: _nameController.text.trim(),
        type: _documentTypes[_documentType]!,
        documentDate: _dateController.text.trim().isEmpty
            ? null
            : parseDocumentDate(_dateController.text),
      ),
      attempt: _attempt,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _uploading = false;
          if (failure.code == 'VALIDATION_ERROR' &&
              failure.fieldErrors.isNotEmpty) {
            _errors = failure.fieldErrors;
          } else {
            _failure = failure;
          }
        });
    }
  }

  String? _error(String field, OmniLocalizations l10n) {
    final kind = _errors[field];
    return kind == null ? null : recordFieldMessage(field, kind, l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final failure = _failure;
    return Scaffold(
      backgroundColor: OmniColors.slateSoft,
      appBar: AppBar(
        title: Text('Documents Médicaux de ${widget.patientName}'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Fermer',
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documents Médicaux',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: OmniColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Nom du Document'),
                        TextField(
                          controller: _nameController,
                          onChanged: (_) => _edited(),
                          decoration: InputDecoration(
                            hintText: 'Ex: Rapport d\'Analyse de Sang',
                            errorText: _error('title', l10n),
                            errorMaxLines: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _FieldLabel('Type de Document'),
                        DropdownButtonFormField<String>(
                          initialValue: _documentType,
                          decoration: const InputDecoration(),
                          items: const [
                            DropdownMenuItem(
                              value: 'Autre',
                              child: Text('Autre'),
                            ),
                            DropdownMenuItem(
                              value: 'Analyse',
                              child: Text('Analyse'),
                            ),
                            DropdownMenuItem(
                              value: 'Ordonnance',
                              child: Text('Ordonnance'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _documentType = value);
                              _edited();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _FieldLabel('Date du Document'),
                        TextField(
                          controller: _dateController,
                          keyboardType: TextInputType.datetime,
                          onChanged: (_) => _edited(),
                          decoration: InputDecoration(
                            hintText: 'dd/mm/yyyy',
                            errorText: _error('documentDate', l10n),
                            errorMaxLines: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _FieldLabel('Fichier du Document'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              // Shows the picked file's name; a file is
                              // chosen with « Télécharger », never typed.
                              child: TextField(
                                controller: _urlController,
                                readOnly: true,
                                onTap: _uploading ? null : _pickFile,
                                decoration: InputDecoration(
                                  hintText: 'URL du fichier',
                                  prefixIcon: const Icon(Icons.link_rounded),
                                  errorText: _error('file', l10n),
                                  errorMaxLines: 3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _uploading ? null : _pickFile,
                              icon: const Icon(
                                Icons.upload_file_outlined,
                                size: 18,
                              ),
                              label: const Text('Télécharger'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: _uploading ? null : _clearForm,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Supprimer ce document'),
                          style: TextButton.styleFrom(
                            foregroundColor: OmniColors.error,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        if (failure != null) ...[
                          const SizedBox(height: 8),
                          PassportCardStatusBody(
                            status: PassportCardFailed(
                              message: recordFailureMessage(
                                failure,
                                l10n,
                                fallback: l10n.saveGeneric,
                              ),
                              onRetry: _save,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton(
            onPressed: _uploading ? null : _save,
            child: const Text('Enregistrer les Modifications'),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
