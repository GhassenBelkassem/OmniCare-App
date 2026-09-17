import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';

class MedicalDocumentEditorScreen extends StatefulWidget {
  final String patientName;

  const MedicalDocumentEditorScreen({super.key, required this.patientName});

  @override
  State<MedicalDocumentEditorScreen> createState() =>
      _MedicalDocumentEditorScreenState();
}

class _MedicalDocumentEditorScreenState
    extends State<MedicalDocumentEditorScreen> {
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _urlController = TextEditingController();
  String _documentType = 'Autre';
  bool _hasStaticFile = false;

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          decoration: const InputDecoration(
                            hintText: 'Ex: Rapport d\'Analyse de Sang',
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
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _FieldLabel('Date du Document'),
                        TextField(
                          controller: _dateController,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            hintText: 'dd/mm/yyyy',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _FieldLabel('Fichier du Document'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _urlController,
                                decoration: InputDecoration(
                                  hintText: 'URL du fichier',
                                  prefixIcon: const Icon(Icons.link_rounded),
                                  helperText: _hasStaticFile
                                      ? 'Fichier simulé prêt'
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _hasStaticFile = true;
                                  _urlController.text =
                                      'document-medical-demo.pdf';
                                });
                              },
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
                          onPressed: () {
                            setState(() {
                              _nameController.clear();
                              _dateController.clear();
                              _urlController.clear();
                              _hasStaticFile = false;
                            });
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Supprimer ce document'),
                          style: TextButton.styleFrom(
                            foregroundColor: OmniColors.error,
                            padding: EdgeInsets.zero,
                          ),
                        ),
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
            onPressed: () {
              Navigator.of(context).pop(true);
            },
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
