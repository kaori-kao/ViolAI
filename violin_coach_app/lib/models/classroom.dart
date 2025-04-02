class Classroom {
  final String id;
  final String name;
  final String description;
  final String teacherId;
  final String joinCode;
  final DateTime createdAt;
  final int studentCount;
  
  Classroom({
    required this.id,
    required this.name,
    required this.description,
    required this.teacherId,
    required this.joinCode,
    required this.createdAt,
    this.studentCount = 0,
  });
  
  factory Classroom.fromJson(Map<String, dynamic> json) {
    return Classroom(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      teacherId: json['teacher_id'],
      joinCode: json['join_code'],
      createdAt: DateTime.parse(json['created_at']),
      studentCount: json['student_count'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'teacher_id': teacherId,
      'join_code': joinCode,
      'created_at': createdAt.toIso8601String(),
      'student_count': studentCount,
    };
  }
  
  Classroom copyWith({
    String? id,
    String? name,
    String? description,
    String? teacherId,
    String? joinCode,
    DateTime? createdAt,
    int? studentCount,
  }) {
    return Classroom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      teacherId: teacherId ?? this.teacherId,
      joinCode: joinCode ?? this.joinCode,
      createdAt: createdAt ?? this.createdAt,
      studentCount: studentCount ?? this.studentCount,
    );
  }
  
  @override
  String toString() {
    return 'Classroom(id: $id, name: $name, students: $studentCount)';
  }
}

class ClassroomStudent {
  final String classroomId;
  final String userId;
  final DateTime joinedAt;
  
  ClassroomStudent({
    required this.classroomId,
    required this.userId,
    required this.joinedAt,
  });
  
  factory ClassroomStudent.fromJson(Map<String, dynamic> json) {
    return ClassroomStudent(
      classroomId: json['classroom_id'],
      userId: json['user_id'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'classroom_id': classroomId,
      'user_id': userId,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
  
  @override
  String toString() {
    return 'ClassroomStudent(classroomId: $classroomId, userId: $userId)';
  }
}

class Assignment {
  final String id;
  final String classroomId;
  final String title;
  final String description;
  final DateTime dueDate;
  final DateTime createdAt;
  
  Assignment({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.createdAt,
  });
  
  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'],
      classroomId: json['classroom_id'],
      title: json['title'],
      description: json['description'] ?? '',
      dueDate: DateTime.parse(json['due_date']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'classroom_id': classroomId,
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  Assignment copyWith({
    String? id,
    String? classroomId,
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? createdAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      classroomId: classroomId ?? this.classroomId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  @override
  String toString() {
    return 'Assignment(id: $id, title: $title, dueDate: $dueDate)';
  }
}

class AssignmentSubmission {
  final String id;
  final String assignmentId;
  final String userId;
  final String recordingUrl;
  final String? feedback;
  final double? score;
  final DateTime submittedAt;
  
  AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.userId,
    required this.recordingUrl,
    this.feedback,
    this.score,
    required this.submittedAt,
  });
  
  factory AssignmentSubmission.fromJson(Map<String, dynamic> json) {
    return AssignmentSubmission(
      id: json['id'],
      assignmentId: json['assignment_id'],
      userId: json['user_id'],
      recordingUrl: json['recording_url'],
      feedback: json['feedback'],
      score: json['score'] != null ? json['score'].toDouble() : null,
      submittedAt: DateTime.parse(json['submitted_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'user_id': userId,
      'recording_url': recordingUrl,
      'feedback': feedback,
      'score': score,
      'submitted_at': submittedAt.toIso8601String(),
    };
  }
  
  AssignmentSubmission copyWith({
    String? id,
    String? assignmentId,
    String? userId,
    String? recordingUrl,
    String? feedback,
    double? score,
    DateTime? submittedAt,
  }) {
    return AssignmentSubmission(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      userId: userId ?? this.userId,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      feedback: feedback ?? this.feedback,
      score: score ?? this.score,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
  
  @override
  String toString() {
    return 'AssignmentSubmission(id: $id, userId: $userId, score: $score)';
  }
}