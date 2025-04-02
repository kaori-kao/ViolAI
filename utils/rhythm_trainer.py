import time

class RhythmTrainer:
    """
    Class to handle rhythm training for Twinkle Twinkle Little Star pattern
    """
    def __init__(self):
        # Suzuki Book 1 "Twinkle Twinkle Little Star" bowing pattern
        # Alternating down and up bows for A section (16 changes)
        # Repeated for B section (16 more changes)
        self.twinkle_pattern = ["Down bow", "Up bow"] * 16
        self.current_position = 0
        self.last_direction = None
        self.correct_count = 0
        self.incorrect_count = 0
        self.last_update_time = time.time()
        
    def update_progress(self, current_direction):
        """
        Update progress through the song based on detected bow direction
        
        Args:
            current_direction: Current detected bow direction
            
        Returns:
            Tuple of (status message, current progress)
        """
        # Skip if direction not detected or is "Holding"
        if current_direction in ["Not detected", "Calibrating...", "Holding"]:
            return "Waiting for bow movement...", self.current_position
            
        # Check if this is a new direction (not the same as last recorded)
        if current_direction != self.last_direction and self.last_direction is not None:
            # Check if enough time has passed since last update (to avoid rapid changes)
            current_time = time.time()
            if current_time - self.last_update_time < 0.5:  # 500ms minimum between updates
                return self._get_status_message(), self.current_position
                
            # Direction has changed, check if it matches the expected pattern
            expected_direction = self.twinkle_pattern[self.current_position]
            
            if current_direction == expected_direction:
                self.correct_count += 1
                status = f"Correct! {current_direction} detected."
            else:
                self.incorrect_count += 1
                status = f"Oops! Expected {expected_direction}, but detected {current_direction}."
                
            # Move to next position in pattern
            self.current_position = (self.current_position + 1) % len(self.twinkle_pattern)
            self.last_update_time = current_time
        else:
            status = f"Current bow: {current_direction}, next expected: {self.twinkle_pattern[self.current_position]}"
            
        # Update last direction
        self.last_direction = current_direction
        
        return status, self.current_position
    
    def reset_progress(self):
        """
        Reset progress to beginning of song
        """
        self.current_position = 0
        self.last_direction = None
        self.correct_count = 0
        self.incorrect_count = 0
        self.last_update_time = time.time()
        
    def _get_status_message(self):
        """
        Get status message based on current progress
        
        Returns:
            Status message string
        """
        total = self.correct_count + self.incorrect_count
        if total == 0:
            accuracy = 0
        else:
            accuracy = (self.correct_count / total) * 100
            
        next_expected = self.twinkle_pattern[self.current_position]
        
        return f"Progress: {self.current_position}/32 | Next: {next_expected} | Accuracy: {accuracy:.1f}%"
    
    def get_progress_stats(self):
        """
        Get progress statistics
        
        Returns:
            Dictionary of progress statistics
        """
        total = self.correct_count + self.incorrect_count
        if total == 0:
            accuracy = 0
        else:
            accuracy = (self.correct_count / total) * 100
            
        return {
            "position": self.current_position,
            "total_bows": len(self.twinkle_pattern),
            "correct_count": self.correct_count,
            "incorrect_count": self.incorrect_count,
            "accuracy": accuracy
        }
