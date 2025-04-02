import 'dart:convert';
import 'dart:math' as math;

/// A utility class to analyze violin posture compared to calibrated reference.
class PostureAnalyzer {
  // Thresholds for posture quality assessment
  final double _excellentThreshold = 0.05;
  final double _goodThreshold = 0.1;
  final double _fairThreshold = 0.2;
  
  /// Analyze current posture compared to calibrated reference
  Map<String, dynamic> analyzePosture(
    List<List<double>> currentKeypoints,
    String calibrationData,
  ) {
    try {
      // Parse calibration data
      final calibration = json.decode(calibrationData) as Map<String, dynamic>;
      final referenceKeypoints = (calibration['keypoints'] as List)
          .map((e) => (e as List).map((p) => p as double).toList())
          .toList();
      
      // Calculate overall posture difference
      final overallDifference = _calculatePostureDifference(
        currentKeypoints,
        referenceKeypoints,
      );
      
      // Assess posture quality
      String status;
      if (overallDifference < _excellentThreshold) {
        status = 'excellent';
      } else if (overallDifference < _goodThreshold) {
        status = 'good';
      } else if (overallDifference < _fairThreshold) {
        status = 'fair';
      } else {
        status = 'poor';
      }
      
      // Provide detailed feedback
      final feedback = _generateDetailedFeedback(
        currentKeypoints,
        referenceKeypoints,
      );
      
      return {
        'status': status,
        'difference': overallDifference,
        'feedback': feedback,
      };
    } catch (e) {
      // Return error result
      return {
        'status': 'error',
        'difference': 1.0,
        'feedback': 'Error analyzing posture: $e',
      };
    }
  }
  
  /// Calculate the difference between current and reference posture
  double _calculatePostureDifference(
    List<List<double>> current,
    List<List<double>> reference,
  ) {
    // Ensure both lists have same length
    final minLength = math.min(current.length, reference.length);
    
    double totalDifference = 0.0;
    int validPoints = 0;
    
    // Only include points that are meaningful for violin posture
    final importantPoints = [
      0,  // Nose
      5,  // Left shoulder
      6,  // Right shoulder
      7,  // Left elbow
      8,  // Right elbow
      9,  // Left wrist
      10, // Right wrist
      11, // Left hip
      12, // Right hip
    ];
    
    for (final index in importantPoints) {
      if (index < minLength) {
        // Get current and reference point
        final currPoint = current[index];
        final refPoint = reference[index];
        
        // Calculate Euclidean distance in 3D space
        double pointDifference = 0.0;
        for (int i = 0; i < 3; i++) {
          if (i < currPoint.length && i < refPoint.length) {
            pointDifference += math.pow(currPoint[i] - refPoint[i], 2);
          }
        }
        pointDifference = math.sqrt(pointDifference);
        
        // Add to total difference
        totalDifference += pointDifference;
        validPoints++;
      }
    }
    
    // Return average difference
    return validPoints > 0 ? totalDifference / validPoints : 1.0;
  }
  
  /// Generate detailed feedback on posture issues
  Map<String, dynamic> _generateDetailedFeedback(
    List<List<double>> current,
    List<List<double>> reference,
  ) {
    final feedback = <String, dynamic>{};
    
    // Check if shoulders are level
    if (current.length > 6 && reference.length > 6) {
      final currentLeftShoulder = current[5];
      final currentRightShoulder = current[6];
      final refLeftShoulder = reference[5];
      final refRightShoulder = reference[6];
      
      final currentShoulderHeight = currentLeftShoulder[1] - currentRightShoulder[1];
      final refShoulderHeight = refLeftShoulder[1] - refRightShoulder[1];
      final shoulderHeightDiff = (currentShoulderHeight - refShoulderHeight).abs();
      
      if (shoulderHeightDiff > 0.1) {
        feedback['shoulders'] = {
          'status': 'poor',
          'message': 'Your shoulders are not level. Try relaxing your shoulder muscles.',
        };
      } else {
        feedback['shoulders'] = {
          'status': 'good',
          'message': 'Your shoulders are well-positioned.',
        };
      }
    }
    
    // Check violin position (using left arm angles)
    if (current.length > 9 && reference.length > 9) {
      final currentLeftShoulder = current[5];
      final currentLeftElbow = current[7];
      final currentLeftWrist = current[9];
      
      final refLeftShoulder = reference[5];
      final refLeftElbow = reference[7];
      final refLeftWrist = reference[9];
      
      // Calculate angle at left elbow
      final currentElbowAngle = _calculateAngle(
        currentLeftShoulder,
        currentLeftElbow,
        currentLeftWrist,
      );
      
      final refElbowAngle = _calculateAngle(
        refLeftShoulder,
        refLeftElbow,
        refLeftWrist,
      );
      
      final elbowAngleDiff = (currentElbowAngle - refElbowAngle).abs();
      
      if (elbowAngleDiff > 15) {
        feedback['violin_position'] = {
          'status': 'poor',
          'message': 'Your violin position needs adjustment. Check the angle of your left arm.',
        };
      } else {
        feedback['violin_position'] = {
          'status': 'good',
          'message': 'Your violin is well-positioned.',
        };
      }
    }
    
    // Check bow arm position
    if (current.length > 10 && reference.length > 10) {
      final currentRightShoulder = current[6];
      final currentRightElbow = current[8];
      final currentRightWrist = current[10];
      
      final refRightShoulder = reference[6];
      final refRightElbow = reference[8];
      final refRightWrist = reference[10];
      
      // Calculate angle at right elbow
      final currentElbowAngle = _calculateAngle(
        currentRightShoulder,
        currentRightElbow,
        currentRightWrist,
      );
      
      final refElbowAngle = _calculateAngle(
        refRightShoulder,
        refRightElbow,
        refRightWrist,
      );
      
      // We expect the bow arm to move, so just check if it's in a reasonable range
      if (currentElbowAngle < 45 || currentElbowAngle > 150) {
        feedback['bow_arm'] = {
          'status': 'caution',
          'message': 'Watch your bow arm position. Keep your elbow at a comfortable height.',
        };
      } else {
        feedback['bow_arm'] = {
          'status': 'good',
          'message': 'Your bow arm has good positioning.',
        };
      }
    }
    
    return feedback;
  }
  
  /// Calculate angle between three points in 3D space
  double _calculateAngle(List<double> a, List<double> b, List<double> c) {
    // Create vectors
    final vector1 = [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
    final vector2 = [c[0] - b[0], c[1] - b[1], c[2] - b[2]];
    
    // Calculate dot product
    final dotProduct = vector1[0] * vector2[0] + 
                      vector1[1] * vector2[1] + 
                      vector1[2] * vector2[2];
    
    // Calculate magnitudes
    final mag1 = math.sqrt(
      vector1[0] * vector1[0] + 
      vector1[1] * vector1[1] + 
      vector1[2] * vector1[2]
    );
    
    final mag2 = math.sqrt(
      vector2[0] * vector2[0] + 
      vector2[1] * vector2[1] + 
      vector2[2] * vector2[2]
    );
    
    // Calculate angle in radians, handle potential numerical errors
    double angleRad = 0;
    double denominator = mag1 * mag2;
    
    if (denominator > 0) {
      final cosTheta = math.min(1.0, math.max(-1.0, dotProduct / denominator));
      angleRad = math.acos(cosTheta);
    }
    
    // Convert to degrees
    return angleRad * (180 / math.pi);
  }
}