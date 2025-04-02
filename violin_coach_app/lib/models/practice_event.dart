import 'dart:convert';

/// Represents an event that occurred during a violin practice session.
class PracticeEvent {
  final int? id;
  final int sessionId;
  final DateTime timestamp;
  final String eventType;
  final String eventData;

  PracticeEvent({
    this.id,
    required this.sessionId,
    required this.timestamp,
    required this.eventType,
    required this.eventData,
  });

  /// Creates a PracticeEvent from a map (e.g., from database)
  factory PracticeEvent.fromMap(Map<String, dynamic> map) {
    return PracticeEvent(
      id: map['id'],
      sessionId: map['session_id'],
      timestamp: DateTime.parse(map['timestamp']),
      eventType: map['event_type'],
      eventData: map['event_data'],
    );
  }

  /// Converts to a map (e.g., for database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'event_type': eventType,
      'event_data': eventData,
    };
  }
  
  /// Get parsed event data as a Map
  Map<String, dynamic> get parsedData {
    try {
      return json.decode(eventData);
    } catch (e) {
      return {'error': 'Failed to parse event data'};
    }
  }

  /// Converts to JSON string
  String toJson() => json.encode(toMap());

  /// Creates from JSON string
  factory PracticeEvent.fromJson(String source) => 
      PracticeEvent.fromMap(json.decode(source));

  /// Creates a posture correction event
  static PracticeEvent createPostureEvent(
    int sessionId, 
    String status, 
    Map<String, dynamic> feedback,
  ) {
    return PracticeEvent(
      sessionId: sessionId,
      timestamp: DateTime.now(),
      eventType: 'posture_correction',
      eventData: json.encode({
        'status': status,
        'feedback': feedback,
      }),
    );
  }

  /// Creates a bow direction change event
  static PracticeEvent createBowDirectionEvent(
    int sessionId, 
    String direction, 
    double angle,
  ) {
    return PracticeEvent(
      sessionId: sessionId,
      timestamp: DateTime.now(),
      eventType: 'bow_direction_change',
      eventData: json.encode({
        'direction': direction,
        'angle': angle,
      }),
    );
  }

  /// Creates a rhythm progress event
  static PracticeEvent createRhythmEvent(
    int sessionId, 
    String status, 
    int currentNote, 
    int totalNotes,
    double progressPercent,
  ) {
    return PracticeEvent(
      sessionId: sessionId,
      timestamp: DateTime.now(),
      eventType: 'rhythm_progress',
      eventData: json.encode({
        'status': status,
        'current_note': currentNote,
        'total_notes': totalNotes,
        'progress_percent': progressPercent,
      }),
    );
  }
}