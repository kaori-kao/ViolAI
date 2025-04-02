import 'dart:convert';

class CalibrationProfile {
  final int? id;
  final int userId;
  final String name;
  final DateTime createdAt;
  final bool isActive;
  final String calibrationData;

  CalibrationProfile({
    this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.isActive,
    required this.calibrationData,
  });

  factory CalibrationProfile.fromMap(Map<String, dynamic> map) {
    return CalibrationProfile(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
      isActive: map['is_active'] == 1,
      calibrationData: map['calibration_data'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'calibration_data': calibrationData,
    };
  }

  String toJson() => json.encode(toMap());

  factory CalibrationProfile.fromJson(String source) =>
      CalibrationProfile.fromMap(json.decode(source));
      
  Map<String, dynamic> get parsedCalibrationData => 
      json.decode(calibrationData);
}