/// A utility class to handle rhythm training for Twinkle Twinkle Little Star pattern.
class RhythmTrainer {
  // Current progress through the song
  int _currentNoteIndex = 0;
  
  // Total notes in the song
  final int _totalNotes = 42;  // Twinkle Twinkle has 42 notes
  
  // Expected bow direction pattern for the song
  final List<String> _bowDirectionPattern = [
    'Down', 'Up', 'Down', 'Up', 'Down', 'Up', 'Down',  // First phrase
    'Up', 'Down', 'Up', 'Down', 'Up', 'Down', 'Up',    // Second phrase
    'Down', 'Up', 'Down', 'Up', 'Down', 'Up', 'Down',  // Third phrase
    'Up', 'Down', 'Up', 'Down', 'Up', 'Down', 'Up',    // Fourth phrase
    'Down', 'Up', 'Down', 'Up', 'Down', 'Up', 'Down',  // Fifth phrase
    'Up', 'Down', 'Up', 'Down', 'Up', 'Down', 'Up',    // Last phrase
  ];
  
  // Track correct and incorrect bow directions
  int _correctDirections = 0;
  int _incorrectDirections = 0;
  
  // Last direction we detected
  String _lastDirection = '';
  
  /// Update progress through the song based on detected bow direction
  Map<String, dynamic> updateProgress(String currentDirection) {
    // Don't count the same direction twice in a row
    if (currentDirection == _lastDirection) {
      return {
        'status': 'Waiting for new bow stroke...',
        'current_note': _currentNoteIndex + 1,
        'total_notes': _totalNotes,
        'progress_percent': (_currentNoteIndex / _totalNotes),
      };
    }
    
    // Store this direction
    _lastDirection = currentDirection;
    
    // Check if the direction is correct for the current note
    final expectedDirection = _bowDirectionPattern[_currentNoteIndex];
    final isCorrect = currentDirection == expectedDirection;
    
    // Update tracking
    if (isCorrect) {
      _correctDirections++;
    } else {
      _incorrectDirections++;
    }
    
    // Build status message
    String status;
    if (isCorrect) {
      status = 'Good! ${_getPositionInSong()}';
    } else {
      status = 'Try ${expectedDirection.toLowerCase()} bow for this note. ${_getPositionInSong()}';
    }
    
    // Move to next note regardless (to keep them progressing)
    _currentNoteIndex = (_currentNoteIndex + 1) % _totalNotes;
    
    // Calculate progress percentage
    final progressPercent = _currentNoteIndex / _totalNotes;
    
    // Return result
    return {
      'status': status,
      'is_correct': isCorrect,
      'current_note': _currentNoteIndex + 1,
      'total_notes': _totalNotes,
      'progress_percent': progressPercent,
      'accuracy': _calculateAccuracy(),
    };
  }
  
  /// Reset progress to beginning of song
  void reset() {
    _currentNoteIndex = 0;
    _correctDirections = 0;
    _incorrectDirections = 0;
    _lastDirection = '';
  }
  
  /// Get a description of the current position in the song
  String _getPositionInSong() {
    final noteIndex = _currentNoteIndex % _totalNotes;
    
    if (noteIndex == 0) {
      return "Starting 'Twinkle Twinkle Little Star'";
    } else if (noteIndex == 7) {
      return "At 'How I wonder what you are'";
    } else if (noteIndex == 14) {
      return "At 'Up above the world so high'";
    } else if (noteIndex == 21) {
      return "At 'Like a diamond in the sky'";
    } else if (noteIndex == 28) {
      return "Back to 'Twinkle Twinkle Little Star'";
    } else if (noteIndex == 35) {
      return "Finishing with 'How I wonder what you are'";
    } else {
      return "Note ${noteIndex + 1} of $_totalNotes";
    }
  }
  
  /// Calculate current accuracy percentage
  double _calculateAccuracy() {
    final total = _correctDirections + _incorrectDirections;
    if (total == 0) return 0.0;
    return _correctDirections / total;
  }
  
  /// Get statistics about the current progress
  Map<String, dynamic> getProgressStats() {
    return {
      'current_note': _currentNoteIndex + 1,
      'total_notes': _totalNotes,
      'progress_percent': _currentNoteIndex / _totalNotes,
      'correct_directions': _correctDirections,
      'incorrect_directions': _incorrectDirections,
      'accuracy': _calculateAccuracy(),
    };
  }
}