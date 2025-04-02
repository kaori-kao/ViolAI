import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';

/// A service for analyzing audio to detect violin notes and match them with bow direction.
class AudioAnalyzerService {
  // Singleton pattern
  static final AudioAnalyzerService _instance = AudioAnalyzerService._internal();
  factory AudioAnalyzerService() => _instance;
  AudioAnalyzerService._internal();
  
  // Recording properties
  final _recorder = FlutterSoundRecorder();
  final _player = FlutterSoundPlayer();
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  String? _recordingPath;
  String? _currentSessionId;
  StreamSubscription? _recorderSubscription;
  final List<Map<String, dynamic>> _noteEvents = [];
  
  // Violin open string frequencies (Hz)
  static const Map<String, double> _openStringFrequencies = {
    'G3': 196.00,
    'D4': 293.66,
    'A4': 440.00,
    'E5': 659.25,
  };
  
  // Tolerance for frequency matching (cents)
  static const double _frequencyTolerance = 30.0; // +/- 30 cents
  
  /// Initialize the audio analyzer
  Future<void> initialize() async {
    if (_isRecorderInitialized && _isPlayerInitialized) return;
    
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission is required for audio analysis');
    }
    
    // Initialize recorder
    await _recorder.openRecorder();
    _isRecorderInitialized = true;
    
    // Initialize player
    await _player.openPlayer();
    _isPlayerInitialized = true;
  }
  
  /// Start a new practice session recording and analysis
  Future<String> startSession(String userId, String pieceName) async {
    if (!_isRecorderInitialized) {
      await initialize();
    }
    
    if (_isRecording) {
      throw Exception('Already recording');
    }
    
    // Create a new session ID
    final sessionId = const Uuid().v4();
    _currentSessionId = sessionId;
    
    // Save session to database
    final db = DatabaseHelper();
    await db.insert('practice_sessions', {
      'id': sessionId,
      'user_id': userId,
      'start_time': DateTime.now().toIso8601String(),
      'piece_name': pieceName,
    });
    
    // Create a temporary file for the recording
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/practice_${sessionId}.aac';
    _recordingPath = path;
    
    // Start recording
    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
      bitRate: 128000, // 128 kbps
      sampleRate: 44100, // 44.1 kHz
    );
    
    _isRecording = true;
    _isAnalyzing = true;
    _noteEvents.clear();
    
    // Listen to the recording stream for real-time analysis
    _recorderSubscription = _recorder.onProgress?.listen((e) {
      _analyzeAudioBuffer(e);
    });
    
    return sessionId;
  }
  
  /// Stop recording and finalize the session
  Future<Map<String, dynamic>> stopSession({
    double? postureScore,
    double? bowDirectionAccuracy,
    double? rhythmScore,
    String? notes,
  }) async {
    if (!_isRecording || _currentSessionId == null) {
      throw Exception('No active session');
    }
    
    // Stop recording
    await _recorder.stopRecorder();
    _recorderSubscription?.cancel();
    _isRecording = false;
    _isAnalyzing = false;
    
    // Calculate session duration
    final db = DatabaseHelper();
    final sessions = await db.query(
      'practice_sessions',
      where: 'id = ?',
      whereArgs: [_currentSessionId],
    );
    
    if (sessions.isEmpty) {
      throw Exception('Session not found');
    }
    
    final session = sessions.first;
    final startTime = DateTime.parse(session['start_time'] as String);
    final endTime = DateTime.now();
    final durationSeconds = endTime.difference(startTime).inSeconds;
    
    // Update session in database
    await db.update(
      'practice_sessions',
      {
        'end_time': endTime.toIso8601String(),
        'duration_seconds': durationSeconds,
        'posture_score': postureScore,
        'bow_direction_accuracy': bowDirectionAccuracy,
        'rhythm_score': rhythmScore,
        'overall_score': _calculateOverallScore(
          postureScore,
          bowDirectionAccuracy,
          rhythmScore,
        ),
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [_currentSessionId],
    );
    
    // Save note events to database
    for (final event in _noteEvents) {
      await db.insert('note_events', {
        'id': const Uuid().v4(),
        'session_id': _currentSessionId,
        'timestamp': event['timestamp'],
        'note': event['note'],
        'frequency': event['frequency'],
        'duration_ms': event['duration_ms'],
        'bow_direction': event['bow_direction'],
      });
    }
    
    // Return session summary
    return {
      'id': _currentSessionId,
      'duration_seconds': durationSeconds,
      'posture_score': postureScore,
      'bow_direction_accuracy': bowDirectionAccuracy,
      'rhythm_score': rhythmScore,
      'overall_score': _calculateOverallScore(
        postureScore,
        bowDirectionAccuracy,
        rhythmScore,
      ),
      'note_count': _noteEvents.length,
      'recording_path': _recordingPath,
    };
  }
  
  /// Calculate overall score from component scores
  double? _calculateOverallScore(
    double? postureScore,
    double? bowDirectionAccuracy,
    double? rhythmScore,
  ) {
    final scores = <double>[];
    if (postureScore != null) scores.add(postureScore);
    if (bowDirectionAccuracy != null) scores.add(bowDirectionAccuracy);
    if (rhythmScore != null) scores.add(rhythmScore);
    
    if (scores.isEmpty) return null;
    
    return scores.reduce((a, b) => a + b) / scores.length;
  }
  
  /// Analyze audio buffer in real-time
  void _analyzeAudioBuffer(RecordingDisposition e) {
    // This is a simplified version of audio analysis
    // In a real app, this would perform Fast Fourier Transform (FFT)
    // to extract frequency information from the audio buffer
    
    // For demonstration purposes, we'll use a mock analysis
    // that randomly detects notes at intervals
    if (_isAnalyzing && math.Random().nextDouble() > 0.95) {
      _detectAndRecordNote();
    }
  }
  
  /// Detect a note and record it with bow direction
  void _detectAndRecordNote({String? bowDirection}) {
    // Mock note detection
    // In a real app, this would analyze the frequency spectrum to find the fundamental frequency
    final openStrings = _openStringFrequencies.keys.toList();
    final randomNote = openStrings[math.Random().nextInt(openStrings.length)];
    final frequency = _openStringFrequencies[randomNote]!;
    
    // Random slight deviation to simulate real-world tuning variance
    final deviationCents = (math.Random().nextDouble() * 20) - 10; // +/- 10 cents
    final adjustedFrequency = _applyDeviationInCents(frequency, deviationCents);
    
    // Record the note event
    _noteEvents.add({
      'timestamp': DateTime.now().toIso8601String(),
      'note': randomNote,
      'frequency': adjustedFrequency,
      'duration_ms': 500 + math.Random().nextInt(500), // 500-1000ms
      'bow_direction': bowDirection ?? (math.Random().nextBool() ? 'up' : 'down'),
    });
  }
  
  /// Apply a deviation in cents to a frequency
  double _applyDeviationInCents(double frequency, double cents) {
    // Formula: f2 = f1 * 2^(cents/1200)
    return frequency * math.pow(2, cents / 1200);
  }
  
  /// Update bow direction for the most recent note
  void updateBowDirection(String bowDirection) {
    if (_noteEvents.isNotEmpty) {
      _noteEvents.last['bow_direction'] = bowDirection;
    } else {
      // If no note has been detected yet, create one
      _detectAndRecordNote(bowDirection: bowDirection);
    }
  }
  
  /// Get note events for the current session
  List<Map<String, dynamic>> getNoteEvents() {
    return List.from(_noteEvents);
  }
  
  /// Get session history for a user
  Future<List<Map<String, dynamic>>> getSessionHistory(String userId, {int limit = 10}) async {
    try {
      final db = DatabaseHelper();
      
      final results = await db.query(
        'practice_sessions',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'start_time DESC',
        limit: limit,
      );
      
      return results;
    } catch (e) {
      print('Failed to get session history: $e');
      return [];
    }
  }
  
  /// Get note events for a specific session
  Future<List<Map<String, dynamic>>> getSessionNoteEvents(String sessionId) async {
    try {
      final db = DatabaseHelper();
      
      final results = await db.query(
        'note_events',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'timestamp ASC',
      );
      
      return results;
    } catch (e) {
      print('Failed to get session note events: $e');
      return [];
    }
  }
  
  /// Analyze bow-note synchronization for a session
  Future<Map<String, dynamic>> analyzeBowNoteSynchronization(String sessionId) async {
    try {
      final noteEvents = await getSessionNoteEvents(sessionId);
      
      // Count notes with matching and non-matching bow directions
      int matchCount = 0;
      int totalCount = noteEvents.length;
      
      for (final event in noteEvents) {
        final note = event['note'] as String;
        final bowDirection = event['bow_direction'] as String;
        
        // In real analysis, we would have more sophisticated rules
        // For this mock implementation, we'll use a simple rule:
        // - G and D strings should be played with down bow
        // - A and E strings should be played with up bow
        final expectedDirection = note.startsWith('G') || note.startsWith('D')
            ? 'down'
            : 'up';
        
        if (bowDirection == expectedDirection) {
          matchCount++;
        }
      }
      
      // Calculate accuracy percentage
      final accuracy = totalCount > 0
          ? (matchCount / totalCount) * 100
          : 0.0;
      
      return {
        'session_id': sessionId,
        'total_notes': totalCount,
        'matching_notes': matchCount,
        'accuracy_percentage': accuracy,
        'analysis_timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Failed to analyze bow-note synchronization: $e');
      return {
        'session_id': sessionId,
        'error': 'Analysis failed: $e',
      };
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _recorderSubscription?.cancel();
    _recorder.closeRecorder();
    _player.closePlayer();
    _isRecorderInitialized = false;
    _isPlayerInitialized = false;
    _isRecording = false;
    _isAnalyzing = false;
    _recordingPath = null;
    _currentSessionId = null;
    _noteEvents.clear();
  }
}