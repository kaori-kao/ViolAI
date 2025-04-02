import 'dart:convert';

/// Represents a violin practice session.
class PracticeSession {
  final int? id;
  final int userId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final String pieceName;
  final double? postureScore;
  final double? bowDirectionAccuracy;
  final double? rhythmScore;
  final double? noteAccuracy;  // New field for audio detection
  final double? overallScore;
  final String? notes;

  PracticeSession({
    this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    required this.pieceName,
    this.postureScore,
    this.bowDirectionAccuracy,
    this.rhythmScore,
    this.noteAccuracy,
    this.overallScore,
    this.notes,
  });

  /// Creates a PracticeSession from a map (e.g., from database)
  factory PracticeSession.fromMap(Map<String, dynamic> map) {
    return PracticeSession(
      id: map['id'],
      userId: map['user_id'],
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      durationSeconds: map['duration_seconds'],
      pieceName: map['piece_name'],
      postureScore: map['posture_score'],
      bowDirectionAccuracy: map['bow_direction_accuracy'],
      rhythmScore: map['rhythm_score'],
      noteAccuracy: map['note_accuracy'],
      overallScore: map['overall_score'],
      notes: map['notes'],
    );
  }

  /// Converts to a map (e.g., for database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'piece_name': pieceName,
      'posture_score': postureScore,
      'bow_direction_accuracy': bowDirectionAccuracy,
      'rhythm_score': rhythmScore,
      'note_accuracy': noteAccuracy,
      'overall_score': overallScore,
      'notes': notes,
    };
  }

  /// Converts to JSON string
  String toJson() => json.encode(toMap());

  /// Creates from JSON string
  factory PracticeSession.fromJson(String source) => 
      PracticeSession.fromMap(json.decode(source));

  /// Creates a copy of this PracticeSession with given fields replaced with new values
  PracticeSession copyWith({
    int? id,
    int? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    String? pieceName,
    double? postureScore,
    double? bowDirectionAccuracy,
    double? rhythmScore,
    double? noteAccuracy,
    double? overallScore,
    String? notes,
  }) {
    return PracticeSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pieceName: pieceName ?? this.pieceName,
      postureScore: postureScore ?? this.postureScore,
      bowDirectionAccuracy: bowDirectionAccuracy ?? this.bowDirectionAccuracy,
      rhythmScore: rhythmScore ?? this.rhythmScore,
      noteAccuracy: noteAccuracy ?? this.noteAccuracy,
      overallScore: overallScore ?? this.overallScore,
      notes: notes ?? this.notes,
    );
  }

  /// Create an ended session from this session
  PracticeSession endSession({
    double? postureScore,
    double? bowDirectionAccuracy,
    double? rhythmScore,
    double? noteAccuracy,
    double? overallScore,
    String? notes,
  }) {
    final now = DateTime.now();
    final duration = now.difference(startTime).inSeconds;
    
    return copyWith(
      endTime: now,
      durationSeconds: duration,
      postureScore: postureScore,
      bowDirectionAccuracy: bowDirectionAccuracy,
      rhythmScore: rhythmScore,
      noteAccuracy: noteAccuracy,
      overallScore: overallScore,
      notes: notes,
    );
  }
}