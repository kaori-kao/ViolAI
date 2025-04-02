import 'dart:async';
import 'package:flutter/material.dart';
import '../services/audio_analyzer_service.dart';

/// A widget that displays real-time note detection from violin audio
class NoteDetectorWidget extends StatefulWidget {
  final Function(String, double)? onNoteDetected;
  
  const NoteDetectorWidget({
    Key? key,
    this.onNoteDetected,
  }) : super(key: key);

  @override
  _NoteDetectorWidgetState createState() => _NoteDetectorWidgetState();
}

class _NoteDetectorWidgetState extends State<NoteDetectorWidget> {
  final AudioAnalyzerService _audioAnalyzer = AudioAnalyzerService();
  String _currentNote = '';
  double _currentFrequency = 0.0;
  double _confidence = 0.0;
  bool _isAnalyzing = false;
  StreamSubscription? _noteSubscription;
  
  @override
  void initState() {
    super.initState();
    _initializeAnalyzer();
  }
  
  @override
  void dispose() {
    _stopAnalysis();
    _noteSubscription?.cancel();
    super.dispose();
  }
  
  Future<void> _initializeAnalyzer() async {
    final initialized = await _audioAnalyzer.initialize();
    
    if (initialized) {
      _subscribeToNoteStream();
    } else {
      _showPermissionError();
    }
  }
  
  void _subscribeToNoteStream() {
    _noteSubscription = _audioAnalyzer.noteStream.listen((noteData) {
      setState(() {
        _currentNote = noteData['note'] as String;
        _currentFrequency = noteData['frequency'] as double;
        _confidence = noteData['confidence'] as double;
      });
      
      if (widget.onNoteDetected != null) {
        widget.onNoteDetected!(_currentNote, _confidence);
      }
    });
  }
  
  void _showPermissionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Microphone permission is required for note detection'),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  Future<void> _toggleAnalysis() async {
    if (_isAnalyzing) {
      await _stopAnalysis();
    } else {
      await _startAnalysis();
    }
  }
  
  Future<void> _startAnalysis() async {
    final started = await _audioAnalyzer.startAnalysis();
    
    if (started) {
      setState(() {
        _isAnalyzing = true;
      });
    }
  }
  
  Future<void> _stopAnalysis() async {
    await _audioAnalyzer.stopAnalysis();
    
    setState(() {
      _isAnalyzing = false;
    });
  }
  
  Color _getNoteColor() {
    if (_confidence >= 0.9) {
      return Colors.green;
    } else if (_confidence >= 0.7) {
      return Colors.yellow;
    } else if (_confidence >= 0.5) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Note Detection',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: Icon(_isAnalyzing ? Icons.mic : Icons.mic_off),
                  color: _isAnalyzing ? Colors.green : Colors.red,
                  onPressed: _toggleAnalysis,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Current note display
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _isAnalyzing
                    ? Text(
                        _currentNote.isEmpty ? '—' : _currentNote,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: _getNoteColor(),
                        ),
                      )
                    : const Text(
                        'Tap the mic to start',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
              ),
            ),
            
            // Frequency display
            if (_isAnalyzing && _currentFrequency > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_currentFrequency.toStringAsFixed(1)} Hz',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ),
            
            // Confidence indicator
            if (_isAnalyzing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  value: _confidence,
                  backgroundColor: Colors.grey[300],
                  color: _getNoteColor(),
                  minHeight: 5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}