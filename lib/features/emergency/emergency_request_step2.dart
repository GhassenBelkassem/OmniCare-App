import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/body_map_widget.dart';

class EmergencyRequestStep2 extends StatefulWidget {
  final Map<String, dynamic> step1Data;

  const EmergencyRequestStep2({
    Key? key,
    required this.step1Data,
  }) : super(key: key);

  @override
  State<EmergencyRequestStep2> createState() => _EmergencyRequestStep2State();
}

class _EmergencyRequestStep2State extends State<EmergencyRequestStep2> {
  final List<String> _selectedBodyParts = [];
  double _painLevel = 5.0;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isRecording = false;
  String? _voiceMessagePath;
  int _recordingDuration = 0;
  bool _isPlaying = false;
  int _playbackPosition = 0;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    return _selectedBodyParts.isNotEmpty && 
           (_descriptionController.text.isNotEmpty || _voiceMessagePath != null);
  }

  void _handleNext() {
    if (!_canProceed()) return;

    final data = {
      ...widget.step1Data,
      'bodyParts': _selectedBodyParts,
      'painLevel': _painLevel.round(),
      'description': _descriptionController.text,
      'voiceMessage': _voiceMessagePath,
    };

    Navigator.pushNamed(
      context,
      '/emergency-step3',
      arguments: data,
    );
  }

  void _toggleBodyPart(String part) {
    setState(() {
      if (_selectedBodyParts.contains(part)) {
        _selectedBodyParts.remove(part);
      } else {
        _selectedBodyParts.add(part);
      }
    });
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
    
    if (_isRecording) {
      // TODO: Start actual voice recording
      // For now, simulate recording with duration counter
      _recordingDuration = 0;
      Future.delayed(const Duration(seconds: 1), _updateRecordingDuration);
    } else {
      // TODO: Stop recording and save audio file
      // Simulate saving voice message
      setState(() {
        _voiceMessagePath = 'voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
      });
    }
  }

  void _updateRecordingDuration() {
    if (_isRecording) {
      setState(() {
        _recordingDuration++;
      });
      Future.delayed(const Duration(seconds: 1), _updateRecordingDuration);
    }
  }

  void _deleteVoiceMessage() {
    setState(() {
      _voiceMessagePath = null;
      _recordingDuration = 0;
      _isPlaying = false;
      _playbackPosition = 0;
    });
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      // TODO: Start actual audio playback
      // For now, simulate playback with position counter
      _playbackPosition = 0;
      Future.delayed(const Duration(milliseconds: 100), _updatePlaybackPosition);
    } else {
      // TODO: Pause audio playback
    }
  }

  void _updatePlaybackPosition() {
    if (_isPlaying && _playbackPosition < _recordingDuration) {
      setState(() {
        _playbackPosition++;
      });
      Future.delayed(const Duration(seconds: 1), _updatePlaybackPosition);
    } else if (_playbackPosition >= _recordingDuration) {
      setState(() {
        _isPlaying = false;
        _playbackPosition = 0;
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getPainColor() {
    if (_painLevel <= 3) return const Color(0xFF6BE3B2);
    if (_painLevel <= 6) return const Color(0xFFFFA500);
    return const Color(0xFFEF4444);
  }

  String _getPainLabel() {
    if (_painLevel <= 3) return 'Légère';
    if (_painLevel <= 6) return 'Modérée';
    return 'Sévère';
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
          'Demande Urgente',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Où avez-vous mal ?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cliquez sur une ou plusieurs zones du corps pour indiquer les zones affectées',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF667085),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    MuscleAnatomyMap(
                      selectedParts: _selectedBodyParts,
                      onPartClick: (part) {
                        setState(() {
                          if (_selectedBodyParts.contains(part)) {
                            _selectedBodyParts.remove(part);
                          } else {
                            _selectedBodyParts.add(part);
                          }
                        });
                      },
                      onReset: () {
                        setState(() {
                          _selectedBodyParts.clear();
                        });
                      },
                    ),
                    if (_selectedBodyParts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSelectedAreas(),
                    ],
                    const SizedBox(height: 32),
                    _buildPainLevelSlider(),
                    const SizedBox(height: 32),
                    _buildDescriptionInput(),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1A202C),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.arrow_back, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Retour',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _canProceed() ? _handleNext : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1FBF9A),
                              disabledBackgroundColor: const Color(0xFFE2E8F0),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Étape Suivante',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _canProceed() ? Colors.white : const Color(0xFF9CA3AF),
                              ),
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
        ],
      ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildProgressStep(1, true)),
              const SizedBox(width: 8),
              Expanded(child: _buildProgressStep(2, true)),
              const SizedBox(width: 8),
              Expanded(child: _buildProgressStep(3, false)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Étape 2 sur 3',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, bool isActive) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1FBF9A) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSelectedAreas() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1FBF9A).withOpacity(0.05),
        border: Border.all(
          color: const Color(0xFF1FBF9A).withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zones Sélectionnées (${_selectedBodyParts.length})',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedBodyParts.map((part) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      muscleParts[part] ?? part,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedBodyParts.remove(part);
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPainLevelSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Niveau de Douleur',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getPainColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_painLevel.round()}/10 - ${_getPainLabel()}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _getPainColor(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _getPainColor(),
            inactiveTrackColor: const Color(0xFFE2E8F0),
            thumbColor: _getPainColor(),
            overlayColor: _getPainColor().withOpacity(0.2),
            trackHeight: 6,
          ),
          child: Slider(
            value: _painLevel,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (value) {
              setState(() {
                _painLevel = value;
              });
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1 - Légère',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF667085),
              ),
            ),
            Text(
              '10 - Sévère',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Description des Symptômes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Décrivez vos symptômes en détail...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: const Color(0xFFF4F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
                ),
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 60, 16),
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF1A202C),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleRecording,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isRecording 
                          ? const Color(0xFFEF4444).withOpacity(0.1)
                          : const Color(0xFF1FBF9A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: _isRecording 
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF1FBF9A),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isRecording)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Enregistrement en cours...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(_recordingDuration),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_voiceMessagePath != null && !_isRecording)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1FBF9A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1FBF9A).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _togglePlayback,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1FBF9A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1FBF9A).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _recordingDuration > 0 
                                      ? _playbackPosition / _recordingDuration 
                                      : 0.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1FBF9A),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatDuration(_playbackPosition)} / ${_formatDuration(_recordingDuration)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _deleteVoiceMessage,
                    icon: const Icon(Icons.delete_outline),
                    color: const Color(0xFFEF4444),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
