import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/classroom.dart';
import '../models/user.dart';
import 'auth_service.dart';

/// A service that handles classroom-related operations.
class ClassroomService {
  // Singleton pattern
  static final ClassroomService _instance = ClassroomService._internal();
  factory ClassroomService() => _instance;
  ClassroomService._internal();
  
  final AuthService _authService = AuthService();
  
  // In-memory storage for classrooms
  final Map<String, Map<String, dynamic>> _classrooms = {
    // Sample classroom data
    '123e4567-e89b-12d3-a456-426614174000': {
      'id': '123e4567-e89b-12d3-a456-426614174000',
      'name': 'Beginner Violin Class',
      'description': 'For students learning Suzuki Book 1',
      'teacher_id': '9f8e3e1d-4c9e-4f5a-8a7b-9d1a7c5e4f3d', // Teacher's ID
      'join_code': 'VIOLIN123',
      'created_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      'student_count': 2,
    },
    '223e4567-e89b-12d3-a456-426614174001': {
      'id': '223e4567-e89b-12d3-a456-426614174001',
      'name': 'Intermediate Violin Class',
      'description': 'For students learning Suzuki Book 2-3',
      'teacher_id': '9f8e3e1d-4c9e-4f5a-8a7b-9d1a7c5e4f3d', // Teacher's ID
      'join_code': 'VIOLIN456',
      'created_at': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
      'student_count': 1,
    },
  };
  
  // Student-classroom relationships
  final List<Map<String, dynamic>> _classroomStudents = [
    {
      'classroom_id': '123e4567-e89b-12d3-a456-426614174000',
      'user_id': '1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p', // Student's ID
      'joined_at': DateTime.now().subtract(const Duration(days: 28)).toIso8601String(),
    },
    {
      'classroom_id': '223e4567-e89b-12d3-a456-426614174001',
      'user_id': '1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p', // Student's ID
      'joined_at': DateTime.now().subtract(const Duration(days: 14)).toIso8601String(),
    },
  ];
  
  // Assignments
  final List<Map<String, dynamic>> _assignments = [
    {
      'id': '323e4567-e89b-12d3-a456-426614174002',
      'classroom_id': '123e4567-e89b-12d3-a456-426614174000',
      'title': 'Twinkle Variations',
      'description': 'Practice all Twinkle variations with proper bow direction changes.',
      'due_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    },
  ];
  
  // Submissions
  final List<Map<String, dynamic>> _submissions = [];
  
  // Get classrooms where current user is the teacher
  Future<List<Classroom>> getTeacherClassrooms() async {
    final currentUser = _authService.currentUser;
    
    if (currentUser == null || !currentUser.isTeacher) {
      return [];
    }
    
    final teacherClassrooms = _classrooms.values
        .where((c) => c['teacher_id'] == currentUser.id)
        .map((c) => Classroom.fromJson(c))
        .toList();
    
    return teacherClassrooms;
  }
  
  // Get classrooms where current user is a student
  Future<List<Classroom>> getStudentClassrooms() async {
    final currentUser = _authService.currentUser;
    
    if (currentUser == null || !currentUser.isStudent) {
      return [];
    }
    
    // Get classroom IDs where user is a student
    final classroomIds = _classroomStudents
        .where((cs) => cs['user_id'] == currentUser.id)
        .map((cs) => cs['classroom_id'] as String)
        .toList();
    
    // Get the classrooms
    final studentClassrooms = classroomIds
        .map((id) => _classrooms[id])
        .where((c) => c != null)
        .map((c) => Classroom.fromJson(c!))
        .toList();
    
    return studentClassrooms;
  }
  
  // Create a new classroom
  Future<Classroom> createClassroom({
    required String name,
    String description = '',
  }) async {
    final currentUser = _authService.currentUser;
    
    if (currentUser == null || !currentUser.isTeacher) {
      throw Exception('Only teachers can create classrooms');
    }
    
    // Generate a random 8-character join code
    final joinCode = _generateJoinCode();
    
    // Create classroom
    final classroomId = const Uuid().v4();
    final classroom = {
      'id': classroomId,
      'name': name,
      'description': description,
      'teacher_id': currentUser.id,
      'join_code': joinCode,
      'created_at': DateTime.now().toIso8601String(),
      'student_count': 0,
    };
    
    // Save to in-memory storage
    _classrooms[classroomId] = classroom;
    
    return Classroom.fromJson(classroom);
  }
  
  // Get classroom by ID
  Future<Classroom?> getClassroomById(String classroomId) async {
    final classroom = _classrooms[classroomId];
    
    if (classroom == null) {
      return null;
    }
    
    return Classroom.fromJson(classroom);
  }
  
  // Update classroom
  Future<Classroom> updateClassroom({
    required String classroomId,
    String? name,
    String? description,
  }) async {
    final currentUser = _authService.currentUser;
    final classroom = _classrooms[classroomId];
    
    if (currentUser == null || !currentUser.isTeacher) {
      throw Exception('Only teachers can update classrooms');
    }
    
    if (classroom == null) {
      throw Exception('Classroom not found');
    }
    
    if (classroom['teacher_id'] != currentUser.id) {
      throw Exception('You can only update your own classrooms');
    }
    
    // Update fields
    if (name != null) classroom['name'] = name;
    if (description != null) classroom['description'] = description;
    
    return Classroom.fromJson(classroom);
  }
  
  // Delete classroom
  Future<void> deleteClassroom(String classroomId) async {
    final currentUser = _authService.currentUser;
    final classroom = _classrooms[classroomId];
    
    if (currentUser == null || !currentUser.isTeacher) {
      throw Exception('Only teachers can delete classrooms');
    }
    
    if (classroom == null) {
      throw Exception('Classroom not found');
    }
    
    if (classroom['teacher_id'] != currentUser.id) {
      throw Exception('You can only delete your own classrooms');
    }
    
    // Remove classroom
    _classrooms.remove(classroomId);
    
    // Remove student relationships
    _classroomStudents.removeWhere((cs) => cs['classroom_id'] == classroomId);
    
    // Remove assignments
    _assignments.removeWhere((a) => a['classroom_id'] == classroomId);
    
    // Remove submissions for those assignments
    final assignmentIds = _assignments
        .where((a) => a['classroom_id'] == classroomId)
        .map((a) => a['id'] as String)
        .toList();
    
    _submissions.removeWhere((s) => assignmentIds.contains(s['assignment_id']));
  }
  
  // Join a classroom with code
  Future<Classroom> joinClassroom(String joinCode) async {
    final currentUser = _authService.currentUser;
    
    if (currentUser == null || !currentUser.isStudent) {
      throw Exception('Only students can join classrooms');
    }
    
    // Find classroom by join code
    final classroom = _classrooms.values.firstWhere(
      (c) => c['join_code'] == joinCode,
      orElse: () => <String, dynamic>{},
    );
    
    if (classroom.isEmpty) {
      throw Exception('Invalid join code');
    }
    
    final classroomId = classroom['id'] as String;
    
    // Check if already joined
    final alreadyJoined = _classroomStudents.any(
      (cs) => cs['classroom_id'] == classroomId && cs['user_id'] == currentUser.id,
    );
    
    if (alreadyJoined) {
      throw Exception('You have already joined this classroom');
    }
    
    // Join classroom
    _classroomStudents.add({
      'classroom_id': classroomId,
      'user_id': currentUser.id,
      'joined_at': DateTime.now().toIso8601String(),
    });
    
    // Update student count
    classroom['student_count'] = (classroom['student_count'] as int) + 1;
    
    return Classroom.fromJson(classroom);
  }
  
  // Leave a classroom
  Future<void> leaveClassroom(String classroomId) async {
    final currentUser = _authService.currentUser;
    
    if (currentUser == null || !currentUser.isStudent) {
      throw Exception('Only students can leave classrooms');
    }
    
    final classroom = _classrooms[classroomId];
    
    if (classroom == null) {
      throw Exception('Classroom not found');
    }
    
    // Check if joined
    final relationship = _classroomStudents.firstWhere(
      (cs) => cs['classroom_id'] == classroomId && cs['user_id'] == currentUser.id,
      orElse: () => <String, dynamic>{},
    );
    
    if (relationship.isEmpty) {
      throw Exception('You are not a member of this classroom');
    }
    
    // Leave classroom
    _classroomStudents.removeWhere(
      (cs) => cs['classroom_id'] == classroomId && cs['user_id'] == currentUser.id,
    );
    
    // Update student count
    classroom['student_count'] = max(0, (classroom['student_count'] as int) - 1);
  }
  
  // Get students in a classroom
  Future<List<User>> getClassroomStudents(String classroomId) async {
    final currentUser = _authService.currentUser;
    final classroom = _classrooms[classroomId];
    
    if (currentUser == null) {
      throw Exception('You must be logged in');
    }
    
    if (classroom == null) {
      throw Exception('Classroom not found');
    }
    
    // Only teacher or students in the classroom can see the student list
    final isTeacher = currentUser.isTeacher && classroom['teacher_id'] == currentUser.id;
    final isStudent = currentUser.isStudent && _classroomStudents.any(
      (cs) => cs['classroom_id'] == classroomId && cs['user_id'] == currentUser.id,
    );
    
    if (!isTeacher && !isStudent) {
      throw Exception('You do not have access to this classroom');
    }
    
    // Get student IDs
    final studentIds = _classroomStudents
        .where((cs) => cs['classroom_id'] == classroomId)
        .map((cs) => cs['user_id'] as String)
        .toList();
    
    // Get student users
    final students = <User>[];
    for (final id in studentIds) {
      final user = await _authService.getUserById(id);
      if (user != null) {
        students.add(user);
      }
    }
    
    return students;
  }
  
  // Create an assignment
  Future<Assignment> createAssignment({
    required String classroomId,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    final currentUser = _authService.currentUser;
    final classroom = _classrooms[classroomId];
    
    if (currentUser == null || !currentUser.isTeacher) {
      throw Exception('Only teachers can create assignments');
    }
    
    if (classroom == null) {
      throw Exception('Classroom not found');
    }
    
    if (classroom['teacher_id'] != currentUser.id) {
      throw Exception('You can only create assignments for your own classrooms');
    }
    
    // Create assignment
    final assignmentId = const Uuid().v4();
    final assignment = {
      'id': assignmentId,
      'classroom_id': classroomId,
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };
    
    // Save to in-memory storage
    _assignments.add(assignment);
    
    return Assignment.fromJson(assignment);
  }
  
  // Get assignments for a classroom
  Future<List<Assignment>> getClassroomAssignments(String classroomId) async {
    final currentUser = _authService.currentUser;
    final classroom = _classrooms[classroomId];
    
    if (currentUser == null) {
      throw Exception('You must be logged in');
    }
    
    if (classroom == null) {
      throw Exception('Classroom not found');
    }
    
    // Only teacher or students in the classroom can see assignments
    final isTeacher = currentUser.isTeacher && classroom['teacher_id'] == currentUser.id;
    final isStudent = currentUser.isStudent && _classroomStudents.any(
      (cs) => cs['classroom_id'] == classroomId && cs['user_id'] == currentUser.id,
    );
    
    if (!isTeacher && !isStudent) {
      throw Exception('You do not have access to this classroom');
    }
    
    // Get assignments
    final assignments = _assignments
        .where((a) => a['classroom_id'] == classroomId)
        .map((a) => Assignment.fromJson(a))
        .toList();
    
    return assignments;
  }
  
  // Submit an assignment
  Future<AssignmentSubmission> submitAssignment({
    required String assignmentId,
    required String recordingUrl,
  }) async {
    final currentUser = _authService.currentUser;
    
    if (currentUser == null || !currentUser.isStudent) {
      throw Exception('Only students can submit assignments');
    }
    
    // Find assignment
    final assignment = _assignments.firstWhere(
      (a) => a['id'] == assignmentId,
      orElse: () => <String, dynamic>{},
    );
    
    if (assignment.isEmpty) {
      throw Exception('Assignment not found');
    }
    
    final classroomId = assignment['classroom_id'] as String;
    
    // Check if student is in the classroom
    final isStudentInClass = _classroomStudents.any(
      (cs) => cs['classroom_id'] == classroomId && cs['user_id'] == currentUser.id,
    );
    
    if (!isStudentInClass) {
      throw Exception('You are not a member of this classroom');
    }
    
    // Check if already submitted
    final existingSubmission = _submissions.firstWhere(
      (s) => s['assignment_id'] == assignmentId && s['user_id'] == currentUser.id,
      orElse: () => <String, dynamic>{},
    );
    
    if (existingSubmission.isNotEmpty) {
      throw Exception('You have already submitted this assignment');
    }
    
    // Create submission
    final submissionId = const Uuid().v4();
    final submission = {
      'id': submissionId,
      'assignment_id': assignmentId,
      'user_id': currentUser.id,
      'recording_url': recordingUrl,
      'feedback': null,
      'score': null,
      'submitted_at': DateTime.now().toIso8601String(),
    };
    
    // Save to in-memory storage
    _submissions.add(submission);
    
    return AssignmentSubmission.fromJson(submission);
  }
  
  // Get submissions for an assignment (teacher only)
  Future<List<AssignmentSubmission>> getAssignmentSubmissions(String assignmentId) async {
    final currentUser = _authService.currentUser;
    
    if (currentUser == null || !currentUser.isTeacher) {
      throw Exception('Only teachers can view submissions');
    }
    
    // Find assignment
    final assignment = _assignments.firstWhere(
      (a) => a['id'] == assignmentId,
      orElse: () => <String, dynamic>{},
    );
    
    if (assignment.isEmpty) {
      throw Exception('Assignment not found');
    }
    
    final classroomId = assignment['classroom_id'] as String;
    final classroom = _classrooms[classroomId];
    
    if (classroom == null) {
      throw Exception('Classroom not found');
    }
    
    // Check if teacher owns the classroom
    if (classroom['teacher_id'] != currentUser.id) {
      throw Exception('You can only view submissions for your own classrooms');
    }
    
    // Get submissions
    final submissions = _submissions
        .where((s) => s['assignment_id'] == assignmentId)
        .map((s) => AssignmentSubmission.fromJson(s))
        .toList();
    
    return submissions;
  }
  
  // Get student's submissions (student only sees their own)
  Future<List<AssignmentSubmission>> getStudentSubmissions(String assignmentId) async {
    final currentUser = _authService.currentUser;
    
    if (currentUser == null || !currentUser.isStudent) {
      throw Exception('Only students can view their submissions');
    }
    
    // Find assignment
    final assignment = _assignments.firstWhere(
      (a) => a['id'] == assignmentId,
      orElse: () => <String, dynamic>{},
    );
    
    if (assignment.isEmpty) {
      throw Exception('Assignment not found');
    }
    
    final classroomId = assignment['classroom_id'] as String;
    
    // Check if student is in the classroom
    final isStudentInClass = _classroomStudents.any(
      (cs) => cs['classroom_id'] == classroomId && cs['user_id'] == currentUser.id,
    );
    
    if (!isStudentInClass) {
      throw Exception('You are not a member of this classroom');
    }
    
    // Get student's submissions
    final submissions = _submissions
        .where((s) => s['assignment_id'] == assignmentId && s['user_id'] == currentUser.id)
        .map((s) => AssignmentSubmission.fromJson(s))
        .toList();
    
    return submissions;
  }
  
  // Provide feedback on a submission (teacher only)
  Future<AssignmentSubmission> provideFeedback({
    required String submissionId,
    required String feedback,
    double? score,
  }) async {
    final currentUser = _authService.currentUser;
    
    if (currentUser == null || !currentUser.isTeacher) {
      throw Exception('Only teachers can provide feedback');
    }
    
    // Find submission
    final submissionIndex = _submissions.indexWhere((s) => s['id'] == submissionId);
    
    if (submissionIndex == -1) {
      throw Exception('Submission not found');
    }
    
    final submission = _submissions[submissionIndex];
    final assignmentId = submission['assignment_id'] as String;
    
    // Find assignment
    final assignment = _assignments.firstWhere(
      (a) => a['id'] == assignmentId,
      orElse: () => <String, dynamic>{},
    );
    
    if (assignment.isEmpty) {
      throw Exception('Assignment not found');
    }
    
    final classroomId = assignment['classroom_id'] as String;
    final classroom = _classrooms[classroomId];
    
    if (classroom == null) {
      throw Exception('Classroom not found');
    }
    
    // Check if teacher owns the classroom
    if (classroom['teacher_id'] != currentUser.id) {
      throw Exception('You can only provide feedback for your own classrooms');
    }
    
    // Update submission
    submission['feedback'] = feedback;
    if (score != null) {
      submission['score'] = score;
    }
    
    _submissions[submissionIndex] = submission;
    
    return AssignmentSubmission.fromJson(submission);
  }
  
  // Helper method to generate a random join code
  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    
    String code;
    bool isUnique;
    
    // Keep generating until we get a unique code
    do {
      code = '';
      for (var i = 0; i < 8; i++) {
        code += chars[random.nextInt(chars.length)];
      }
      
      isUnique = !_classrooms.values.any((c) => c['join_code'] == code);
    } while (!isUnique);
    
    return code;
  }
}