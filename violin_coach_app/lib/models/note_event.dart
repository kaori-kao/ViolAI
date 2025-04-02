import 'dart:convert';

/// Represents a detected musical note event during practice.
class NoteEvent {
  final int? id;
  final int sessionId;
  final DateTime timestamp;
  final String noteName;
  final double frequency;
  final double confidence;
  final double? duration;
  final String? bowDirection;

  NoteEvent({
    this.id,
    required this.sessionId,
    required this.timestamp,
    required this.noteName,
    required this.frequency,
    required this.confidence,
    this.duration,
    this.bowDirection,
  });

  /// Creates a NoteEvent from a map (e.g., from database)
  factory NoteEvent.fromMap(Map<String, dynamic> map) {
    return NoteEvent(
      id: map['id'],
      sessionId: map['session_id'],
      timestamp: DateTime.parse(map['timestamp']),
      noteName: map['note_name'],
      frequency: map['frequency'],
      confidence: map['confidence'],
      duration: map['duration'],
      bowDirection: map['bow_direction'],
    );
  }

  /// Converts to a map (e.g., for database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'note_name': noteName,
      'frequency': frequency,
      'confidence': confidence,
      'duration': duration,
      'bow_direction': bowDirection,
    };
  }
  
  /// Creates a copy of this NoteEvent with given fields replaced with new values
  NoteEvent copyWith({
    int? id,
    int? sessionId,
    DateTime? timestamp,
    String? noteName,
    double? frequency,
    double? confidence,
    double? duration,
    String? bowDirection,
  }) {
    return NoteEvent(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      noteName: noteName ?? this.noteName,
      frequency: frequency ?? this.frequency,
      confidence: confidence ?? this.confidence,
      duration: duration ?? this.duration,
      bowDirection: bowDirection ?? this.bowDirection,
    );
  }
  
  /// Add bow direction to a note event (after it's detected)
  NoteEvent withBowDirection(String direction) {
    return copyWith(bowDirection: direction);
  }
  
  /// Update duration of a note (when note ends)
  NoteEvent withDuration(double noteSeconds) {
    return copyWith(duration: noteSeconds);
  }
  
  /// Check if this note is in the expected pattern for Twinkle Twinkle
  bool isCorrectNote(int position) {
    // The pattern of notes for Twinkle Twinkle Little Star
    final notePattern = [
      'C4', 'C4', 'G4', 'G4', 'A4', 'A4', 'G4',  // First phrase
      'F4', 'F4', 'E4', 'E4', 'D4', 'D4', 'C4',  // Second phrase
      'G4', 'G4', 'F4', 'F4', 'E4', 'E4', 'D4',  // Third phrase
      'G4', 'G4', 'F4', 'F4', 'E4', 'E4', 'D4',  // Fourth phrase
      'C4', 'C4', 'G4', 'G4', 'A4', 'A4', 'G4',  // Fifth phrase
      'F4', 'F4', 'E4', 'E4', 'D4', 'D4', 'C4',  // Last phrase
    ];
    
    if (position < 0 || position >= notePattern.length) {
      return false;
    }
    
    return noteName == notePattern[position];
  }
  
  /// Evaluate bow-note synchronization
  double evaluateSynchronization() {
    // If no bow direction recorded, can't evaluate
    if (bowDirection == null) return 0.0;
    
    // The correct bow direction per note position in Twinkle Twinkle
    final bowPattern = [
      'Down', 'Up', 'Down', 'Up', 'Down', 'Up', 'Down',  // First phrase
      'Up', 'Down', 'Up', 'Down', 'Up', 'Down', 'Up',    // Second phrase
      'Down', 'Up', 'Down', 'Up', 'Down', 'Up', 'Down',  // Third phrase
      'Up', 'Down', 'Up', 'Down', 'Up', 'Down', 'Up',    // Fourth phrase
      'Down', 'Up', 'Down', 'Up', 'Down', 'Up', 'Down',  // Fifth phrase
      'Up', 'Down', 'Up', 'Down', 'Up', 'Down', 'Up',    // Last phrase
    ];
    
    // Determine the note position by the name of the note
    final notePattern = [
      'C4', 'C4', 'G4', 'G4', 'A4', 'A4', 'G4',  // First phrase
      'F4', 'F4', 'E4', 'E4', 'D4', 'D4', 'C4',  // Second phrase
      'G4', 'G4', 'F4', 'F4', 'E4', 'E4', 'D4',  // Third phrase
      'G4', 'G4', 'F4', 'F4', 'E4', 'E4', 'D4',  // Fourth phrase
      'C4', 'C4', 'G4', 'G4', 'A4', 'A4', 'G4',  // Fifth phrase
      'F4', 'F4', 'E4', 'E4', 'D4', 'D4', 'C4',  // Last phrase
    ];
    
    // Find potential positions for this note
    List<int> possiblePositions = [];
    for (int i = 0; i < notePattern.length; i++) {
      if (notePattern[i] == noteName) {
        possiblePositions.add(i);
      }
    }
    
    if (possiblePositions.isEmpty) {
      return 0.0; // Not part of the expected melody
    }
    
    // Check if bow direction matches any of the possible positions
    for (final position in possiblePositions) {
      if (bowPattern[position] == bowDirection) {
        return 1.0; // Perfect match
      }
    }
    
    return 0.0; // Bow direction doesn't match the note
  }

  /// Converts to JSON string
  String toJson() => json.encode(toMap());

  /// Creates from JSON string
  factory NoteEvent.fromJson(String source) => 
      NoteEvent.fromMap(json.decode(source));
}