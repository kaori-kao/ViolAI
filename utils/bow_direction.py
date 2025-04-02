import numpy as np
import time
import cv2
from utils.angle_calculator import AngleCalculator

class BowDirectionDetector:
    """
    Class to detect violin bow direction from pose landmarks
    """
    def __init__(self):
        self.angle_calculator = AngleCalculator()
        self.angle_history = []
        self.max_history = 5  # For moving average (5 frames)
        self.direction_history = []
        self.max_direction_history = 3  # For debounce
        self.last_direction_change = time.time()
        self.debounce_period = 0.4  # Debounce period in seconds (400ms)
        self.current_direction = "Not detected"
        # Add state detection for smoother transitions between bow states
        self.state_confidence = {
            "Up bow": 0,
            "Down bow": 0,
            "Holding": 0
        }
        self.confidence_threshold = 3  # Number of consistent readings to change state
        
    def detect_bow_direction(self, landmarks, frame=None):
        """
        Detect bow direction based on elbow angle changes
        
        Args:
            landmarks: MediaPipe pose landmarks
            frame: Optional video frame for visualization
            
        Returns:
            Tuple of (direction string, current elbow angle)
        """
        if not landmarks:
            return "Not detected", None
            
        # Calculate current elbow angle
        current_angle = self.angle_calculator.calculate_elbow_angle(landmarks)
        
        if current_angle is None:
            return "Not detected", None
            
        # Add to history for smoothing and trend analysis
        self.angle_history.append(current_angle)
        if len(self.angle_history) > self.max_history:
            self.angle_history.pop(0)
            
        # Need at least 3 points to detect direction
        if len(self.angle_history) < 3:
            return "Calibrating...", current_angle
            
        # Calculate the trend (slope) of the angle change
        # Use a more sophisticated approach to detect trends:
        # 1. Use the full history for a more stable measurement
        # 2. Calculate the average rate of change over time
        angle_changes = [self.angle_history[i] - self.angle_history[i-1] for i in range(1, len(self.angle_history))]
        avg_change = sum(angle_changes) / len(angle_changes)
        
        # Determine direction based on angle trend
        # Increasing angle = down bow, decreasing angle = up bow
        # Apply a threshold to avoid minor fluctuations
        threshold = 1.5  # Slightly reduced threshold for better sensitivity
        
        # Increment confidence for the detected direction
        if avg_change > threshold:
            detected_direction = "Down bow"
            self.state_confidence["Down bow"] += 1
            self.state_confidence["Up bow"] = max(0, self.state_confidence["Up bow"] - 1)
            self.state_confidence["Holding"] = max(0, self.state_confidence["Holding"] - 1)
        elif avg_change < -threshold:
            detected_direction = "Up bow"
            self.state_confidence["Up bow"] += 1
            self.state_confidence["Down bow"] = max(0, self.state_confidence["Down bow"] - 1)
            self.state_confidence["Holding"] = max(0, self.state_confidence["Holding"] - 1)
        else:
            detected_direction = "Holding"
            self.state_confidence["Holding"] += 1
            self.state_confidence["Up bow"] = max(0, self.state_confidence["Up bow"] - 1)
            self.state_confidence["Down bow"] = max(0, self.state_confidence["Down bow"] - 1)
        
        # Determine the most confident direction
        most_confident_direction = max(self.state_confidence, key=self.state_confidence.get)
        confidence_value = self.state_confidence[most_confident_direction]
        
        # Only change direction if confidence exceeds threshold
        if confidence_value >= self.confidence_threshold:
            direction = most_confident_direction
        else:
            direction = self.current_direction
            
        # Apply debounce to prevent rapid direction changes
        current_time = time.time()
        if direction != self.current_direction and (current_time - self.last_direction_change) > self.debounce_period:
            self.current_direction = direction
            self.last_direction_change = current_time
            # Reset confidence after a direction change
            if direction != "Holding":  # Don't reset on holding to allow quick transitions from holding
                self.state_confidence = {k: 0 for k in self.state_confidence}
                self.state_confidence[direction] = self.confidence_threshold  # Start with threshold confidence
            
        # Add to direction history
        self.direction_history.append(self.current_direction)
        if len(self.direction_history) > self.max_direction_history:
            self.direction_history.pop(0)
            
        # If frame is provided, visualize the angle and direction
        if frame is not None and landmarks:
            self._visualize_bow_direction(frame, landmarks, self.current_direction, current_angle)
            
        return self.current_direction, current_angle
    
    def _visualize_bow_direction(self, frame, landmarks, direction, angle):
        """
        Visualize bow direction on the frame
        
        Args:
            frame: Video frame
            landmarks: MediaPipe pose landmarks
            direction: Current bow direction
            angle: Current elbow angle
        """
        h, w = frame.shape[:2]
        
        # Get key points
        right_shoulder = (int(landmarks.landmark[12].x * w), int(landmarks.landmark[12].y * h))
        right_elbow = (int(landmarks.landmark[14].x * w), int(landmarks.landmark[14].y * h))
        right_wrist = (int(landmarks.landmark[16].x * w), int(landmarks.landmark[16].y * h))
        
        # Draw arm with color based on direction
        if direction == "Up bow":
            color = (0, 255, 0)  # Green
            # Add directional arrow indicator
            arrow_start = right_elbow
            arrow_end = (right_elbow[0], right_elbow[1] - 50)  # Arrow pointing up
            cv2.arrowedLine(frame, arrow_start, arrow_end, color, 3, tipLength=0.4)
        elif direction == "Down bow":
            color = (0, 0, 255)  # Red
            # Add directional arrow indicator
            arrow_start = right_elbow
            arrow_end = (right_elbow[0], right_elbow[1] + 50)  # Arrow pointing down
            cv2.arrowedLine(frame, arrow_start, arrow_end, color, 3, tipLength=0.4)
        else:
            color = (255, 255, 0)  # Yellow
            
        # Draw arm lines with thicker lines for better visibility
        cv2.line(frame, right_shoulder, right_elbow, color, 3)
        cv2.line(frame, right_elbow, right_wrist, color, 3)
        
        # Draw angle arc
        self._draw_angle_arc(frame, right_shoulder, right_elbow, right_wrist, angle, color)
        
        # Add text for angle with better visibility
        cv2.putText(
            frame, 
            f"Elbow angle: {angle:.1f}°", 
            (right_elbow[0] - 30, right_elbow[1] - 15), 
            cv2.FONT_HERSHEY_SIMPLEX, 
            0.7, 
            color, 
            2
        )
        
        # Add confidence indicator
        most_confident = max(self.state_confidence, key=self.state_confidence.get)
        conf_value = self.state_confidence[most_confident]
        cv2.putText(
            frame,
            f"Confidence: {conf_value}/{self.confidence_threshold}",
            (10, h - 20),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            color,
            1
        )
    
    def _draw_angle_arc(self, frame, p1, p2, p3, angle, color):
        """
        Draw an arc representing the angle between three points
        
        Args:
            frame: Video frame
            p1, p2, p3: Three points where p2 is the vertex
            angle: Angle in degrees
            color: Color tuple for drawing
        """
        # Calculate vectors
        v1 = np.array([p1[0] - p2[0], p1[1] - p2[1]])
        v2 = np.array([p3[0] - p2[0], p3[1] - p2[1]])
        
        # Normalize vectors
        v1_norm = v1 / np.linalg.norm(v1)
        v2_norm = v2 / np.linalg.norm(v2)
        
        # Calculate start angle and end angle
        start_angle = np.arctan2(v1_norm[1], v1_norm[0])
        end_angle = np.arctan2(v2_norm[1], v2_norm[0])
        
        # Convert to degrees
        start_angle_deg = np.degrees(start_angle)
        end_angle_deg = np.degrees(end_angle)
        
        # Ensure correct arc direction
        if end_angle_deg - start_angle_deg > 180:
            end_angle_deg -= 360
        elif end_angle_deg - start_angle_deg < -180:
            end_angle_deg += 360
            
        # Draw arc
        radius = 30
        cv2.ellipse(
            frame, 
            p2, 
            (radius, radius), 
            0, 
            start_angle_deg, 
            end_angle_deg, 
            color, 
            2
        )
