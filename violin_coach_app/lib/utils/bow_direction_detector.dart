import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A utility class to detect and classify violin bow direction.
class BowDirectionDetector {
  // Current state
  String _currentDirection = 'neutral';
  double _currentAngle = 0.0;
  
  // Angle thresholds for direction changes
  final double _angleChangeThreshold = 1.5;
  
  // Angle history for smoothing
  final List<double> _angleHistory = [];
  final int _historySize = 5;
  
  // Direction durations (for holding a direction)
  final Map<String, int> _directionDurations = {
    'Up': 0,
    'Down': 0,
    'Hold': 0,
    'neutral': 0,
  };
  
  /// Detect bow direction based on elbow angle 
  Map<String, dynamic> detectBowDirection(double elbowAngle) {
    // Update angle history
    _angleHistory.add(elbowAngle);
    
    // Keep history at desired size
    if (_angleHistory.length > _historySize) {
      _angleHistory.removeAt(0);
    }
    
    // Need at least 2 points for direction detection
    if (_angleHistory.length < 2) {
      return {
        'direction': _currentDirection,
        'angle': elbowAngle,
        'confidence': 0.0,
      };
    }
    
    // Calculate angle change
    final angleChange = _angleHistory.last - _angleHistory[_angleHistory.length - 2];
    
    // Determine direction based on angle change
    String newDirection;
    double confidence = 0.0;
    
    if (angleChange.abs() < _angleChangeThreshold) {
      newDirection = 'Hold';
      confidence = 1.0 - (angleChange.abs() / _angleChangeThreshold);
    } else if (angleChange > 0) {
      newDirection = 'Up';
      confidence = math.min(1.0, angleChange / (_angleChangeThreshold * 2));
    } else {
      newDirection = 'Down';
      confidence = math.min(1.0, -angleChange / (_angleChangeThreshold * 2));
    }
    
    // Update durations
    _directionDurations[newDirection] = (_directionDurations[newDirection] ?? 0) + 1;
    
    // Reset other direction durations
    for (final key in _directionDurations.keys) {
      if (key != newDirection) {
        _directionDurations[key] = 0;
      }
    }
    
    // Check if direction is stable enough to switch
    final minDuration = 3;
    if ((_directionDurations[newDirection] ?? 0) >= minDuration) {
      _currentDirection = newDirection;
    }
    
    // Store current angle
    _currentAngle = elbowAngle;
    
    return {
      'direction': _currentDirection,
      'angle': elbowAngle,
      'confidence': confidence,
    };
  }
  
  /// Get the current bow direction
  String getCurrentDirection() {
    return _currentDirection;
  }
  
  /// Get a human-readable description of the current bow direction
  String getDirectionDescription() {
    switch (_currentDirection) {
      case 'Up':
        return 'Bow Up';
      case 'Down':
        return 'Bow Down';
      case 'Hold':
        return 'Bow Holding';
      default:
        return 'Waiting for movement';
    }
  }
  
  /// Get a color for the current bow direction
  Color getDirectionColor() {
    switch (_currentDirection) {
      case 'Up':
        return Colors.green;
      case 'Down':
        return Colors.blue;
      case 'Hold':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
  
  /// Reset detector state
  void reset() {
    _currentDirection = 'neutral';
    _angleHistory.clear();
    for (final key in _directionDurations.keys) {
      _directionDurations[key] = 0;
    }
  }
}