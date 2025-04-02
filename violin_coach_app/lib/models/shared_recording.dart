import 'dart:convert';

/// Status types for shared recordings
enum RecordingStatus {
  pending,  // Newly shared, not yet reviewed
  reviewed, // Teacher has reviewed
  archived, // No longer active/relevant
}

/// Represents a violin practice recording shared with a teacher.
class SharedRecording {
  final int? id;
  final int studentId;
  final int? teacherId;
  final int? classroomId;
  final int sessionId;
  final String title;
  final String? description;
  final String recordingUrl;
  final DateTime sharedAt;
  final RecordingStatus status;
  final String? teacherFeedback;
  final DateTime? reviewedAt;
  
  SharedRecording({
    this.id,
    required this.studentId,
    this.teacherId,
    this.classroomId,
    required this.sessionId,
    required this.title,
    this.description,
    required this.recordingUrl,
    required this.sharedAt,
    this.status = RecordingStatus.pending,
    this.teacherFeedback,
    this.reviewedAt,
  });
  
  /// Creates a SharedRecording from a map (e.g., from database)
  factory SharedRecording.fromMap(Map<String, dynamic> map) {
    return SharedRecording(
      id: map['id'],
      studentId: map['student_id'],
      teacherId: map['teacher_id'],
      classroomId: map['classroom_id'],
      sessionId: map['session_id'],
      title: map['title'],
      description: map['description'],
      recordingUrl: map['recording_url'],
      sharedAt: DateTime.parse(map['shared_at']),
      status: RecordingStatus.values.firstWhere(
        (e) => e.toString() == 'RecordingStatus.${map['status']}',
        orElse: () => RecordingStatus.pending,
      ),
      teacherFeedback: map['teacher_feedback'],
      reviewedAt: map['reviewed_at'] != null 
          ? DateTime.parse(map['reviewed_at']) 
          : null,
    );
  }
  
  /// Converts to a map (e.g., for database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'teacher_id': teacherId,
      'classroom_id': classroomId,
      'session_id': sessionId,
      'title': title,
      'description': description,
      'recording_url': recordingUrl,
      'shared_at': sharedAt.toIso8601String(),
      'status': status.toString().split('.').last,
      'teacher_feedback': teacherFeedback,
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }
  
  /// Create a copy of this SharedRecording with given fields replaced with new values
  SharedRecording copyWith({
    int? id,
    int? studentId,
    int? teacherId,
    int? classroomId,
    int? sessionId,
    String? title,
    String? description,
    String? recordingUrl,
    DateTime? sharedAt,
    RecordingStatus? status,
    String? teacherFeedback,
    DateTime? reviewedAt,
  }) {
    return SharedRecording(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      classroomId: classroomId ?? this.classroomId,
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      description: description ?? this.description,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      sharedAt: sharedAt ?? this.sharedAt,
      status: status ?? this.status,
      teacherFeedback: teacherFeedback ?? this.teacherFeedback,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
  
  /// Add teacher feedback to a recording
  SharedRecording withFeedback(String feedback) {
    return copyWith(
      status: RecordingStatus.reviewed,
      teacherFeedback: feedback,
      reviewedAt: DateTime.now(),
    );
  }
  
  /// Archive a recording
  SharedRecording archive() {
    return copyWith(status: RecordingStatus.archived);
  }
  
  /// Converts to JSON string
  String toJson() => json.encode(toMap());
  
  /// Creates from JSON string
  factory SharedRecording.fromJson(String source) => 
      SharedRecording.fromMap(json.decode(source));
}