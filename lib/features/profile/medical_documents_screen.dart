import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../providers/user_onboarding_provider.dart';

class MedicalDocumentsScreen extends StatefulWidget {
  const MedicalDocumentsScreen({super.key});

  @override
  State<MedicalDocumentsScreen> createState() => _MedicalDocumentsScreenState();
}

class _MedicalDocumentsScreenState extends State<MedicalDocumentsScreen> {
  bool _isLoading = false;

  void _showAddDocumentDialog({MedicalDocument? document, int? index}) {
    final nameController = TextEditingController(text: document?.documentName ?? '');
    String documentType = document?.documentType ?? 'Prescription';
    DateTime selectedDate = document?.date ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                document == null ? 'Add Document' : 'Edit Document',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F6F73),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document Name',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: const Color(0xFF1D2939),
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g., Blood Test Results',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: const Color(0xFF9CA3AF),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1FBF9A),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Document Type',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: documentType,
                      onChanged: (value) {
                        setDialogState(() {
                          documentType = value!;
                        });
                      },
                      items: ['Prescription', 'Report', 'Scan', 'Lab Results', 'Other']
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    color: const Color(0xFF1D2939),
                                  ),
                                ),
                              ))
                          .toList(),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1FBF9A),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Date',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF1FBF9A),
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Color(0xFF1D2939),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F5F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMM dd, yyyy').format(selectedDate),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                color: const Color(0xFF1D2939),
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Color(0xFF667085),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      String? filePath;
                      
                      if (document == null) {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                        );
                        
                        if (result != null) {
                          filePath = result.files.single.path;
                        }
                      } else {
                        filePath = document.filePath;
                      }

                      final newDocument = MedicalDocument(
                        documentName: nameController.text,
                        documentType: documentType,
                        date: selectedDate,
                        filePath: filePath,
                      );

                      final provider = Provider.of<UserOnboardingProvider>(
                        context,
                        listen: false,
                      );

                      if (index != null) {
                        provider.removeMedicalDocument(index);
                      }
                      provider.addMedicalDocument(newDocument);

                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    document == null ? 'Add' : 'Update',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _completeProfile() async {
    setState(() => _isLoading = true);

    final provider = Provider.of<UserOnboardingProvider>(context, listen: false);
    final jsonData = provider.toFamilyMemberJson();
    
    print('Medical Passport Data: ${jsonData}');

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medical profile completed successfully!'),
          backgroundColor: Color(0xFF1FBF9A),
        ),
      );
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserOnboardingProvider>(context);

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
          'Medical Profile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1D2939),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
            child: Text(
              'Skip for now',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1FBF9A),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1FBF9A),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '3',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Medical Documents',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F6F73),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Step 3 of 3',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 32),
              if (provider.medicalDocuments.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 64,
                        color: const Color(0xFF667085).withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No documents uploaded yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload your medical documents for easy access',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.medicalDocuments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final document = provider.medicalDocuments[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1FBF9A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.description,
                              color: Color(0xFF1FBF9A),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  document.documentName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1D2939),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${document.documentType} • ${DateFormat('MMM dd, yyyy').format(document.date)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: const Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            color: const Color(0xFF667085),
                            onPressed: () {
                              _showAddDocumentDialog(
                                document: document,
                                index: index,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: const Color(0xFFDC2626),
                            onPressed: () {
                              provider.removeMedicalDocument(index);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _showAddDocumentDialog(),
                icon: const Icon(Icons.add, color: Color(0xFF1FBF9A)),
                label: Text(
                  'Add Document',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1FBF9A),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  side: const BorderSide(color: Color(0xFF1FBF9A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor:
                        const Color(0xFF1FBF9A).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Complete Profile',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
