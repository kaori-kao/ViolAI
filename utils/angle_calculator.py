import numpy as np

class AngleCalculator:
    """
    Class to calculate angles between body parts from pose landmarks
    """
    def __init__(self):
        self.angle_history = []
        self.max_history = 5  # For implementing moving average smoothing
        
    def calculate_elbow_angle(self, landmarks):
        """
        Calculate the angle at the right elbow
        
        Args:
            landmarks: MediaPipe pose landmarks
            
        Returns:
            Angle in degrees
        """
        if not landmarks:
            return None
            
        # Get coordinates for shoulder, elbow, and wrist
        shoulder = landmarks.landmark[12]  # right shoulder
        elbow = landmarks.landmark[14]     # right elbow
        wrist = landmarks.landmark[16]     # right wrist
        
        # Calculate angle
        angle = self._calculate_angle(shoulder, elbow, wrist)
        
        # Add to history for smoothing
        self.angle_history.append(angle)
        if len(self.angle_history) > self.max_history:
            self.angle_history.pop(0)
            
        # Return smoothed angle
        return self.get_smoothed_angle()
    
    def _calculate_angle(self, a, b, c):
        """
        Calculate the angle between three points
        
        Args:
            a, b, c: Three landmarks where b is the vertex
            
        Returns:
            Angle in degrees
        """
        a_vec = np.array([a.x, a.y])
        b_vec = np.array([b.x, b.y])
        c_vec = np.array([c.x, c.y])
        
        ba = a_vec - b_vec
        bc = c_vec - b_vec
        
        cosine_angle = np.dot(ba, bc) / (np.linalg.norm(ba) * np.linalg.norm(bc))
        cosine_angle = np.clip(cosine_angle, -1.0, 1.0)  # Ensure the value is in the valid range
        
        angle = np.arccos(cosine_angle)
        angle_degrees = np.degrees(angle)
        
        return angle_degrees
    
    def get_smoothed_angle(self):
        """
        Get the moving average of the angle history
        
        Returns:
            Smoothed angle in degrees
        """
        if not self.angle_history:
            return None
            
        return sum(self.angle_history) / len(self.angle_history)
    
    def calculate_posture_angles(self, landmarks):
        """
        Calculate key angles for posture analysis
        
        Args:
            landmarks: MediaPipe pose landmarks
            
        Returns:
            Dictionary of posture angles
        """
        if not landmarks:
            return None
            
        # Calculate back angle (between shoulders and hips)
        left_shoulder = landmarks.landmark[11]
        right_shoulder = landmarks.landmark[12]
        left_hip = landmarks.landmark[23]
        right_hip = landmarks.landmark[24]
        nose = landmarks.landmark[0]
        
        # Use midpoints for more stable calculation
        shoulder_mid = self._midpoint(left_shoulder, right_shoulder)
        hip_mid = self._midpoint(left_hip, right_hip)
        
        # Calculate back angle (vertical alignment)
        back_vertical = self._calculate_vertical_angle(shoulder_mid, hip_mid)
        
        # Calculate shoulder angles
        left_shoulder_angle = self._calculate_angle(
            landmarks.landmark[13],  # left elbow
            landmarks.landmark[11],  # left shoulder
            landmarks.landmark[23]   # left hip
        )
        
        right_shoulder_angle = self._calculate_angle(
            landmarks.landmark[14],  # right elbow
            landmarks.landmark[12],  # right shoulder
            landmarks.landmark[24]   # right hip
        )
        
        # Calculate neck angle
        neck_angle = self._calculate_angle(
            nose,
            shoulder_mid,
            hip_mid
        )
        
        return {
            "back_vertical": back_vertical,
            "left_shoulder": left_shoulder_angle,
            "right_shoulder": right_shoulder_angle,
            "neck": neck_angle
        }
    
    def _midpoint(self, p1, p2):
        """
        Calculate the midpoint between two points
        
        Args:
            p1, p2: Two points
            
        Returns:
            Midpoint as a namedtuple with x, y, z attributes
        """
        class Point:
            def __init__(self, x, y, z=0):
                self.x = x
                self.y = y
                self.z = z
                
        return Point((p1.x + p2.x) / 2, (p1.y + p2.y) / 2, (p1.z + p2.z) / 2)
    
    def _calculate_vertical_angle(self, top, bottom):
        """
        Calculate the angle from vertical
        
        Args:
            top, bottom: Two points defining a line
            
        Returns:
            Angle from vertical in degrees
        """
        # Create a vertical line
        vertical_top = type('Point', (), {'x': top.x, 'y': 0})
        vertical_bottom = type('Point', (), {'x': top.x, 'y': 1})
        
        # Get vectors
        line_vector = np.array([bottom.x - top.x, bottom.y - top.y])
        vertical_vector = np.array([vertical_bottom.x - vertical_top.x, vertical_bottom.y - vertical_top.y])
        
        # Calculate angle
        dot_product = np.dot(line_vector, vertical_vector)
        line_magnitude = np.linalg.norm(line_vector)
        vertical_magnitude = np.linalg.norm(vertical_vector)
        
        cosine_angle = dot_product / (line_magnitude * vertical_magnitude)
        cosine_angle = np.clip(cosine_angle, -1.0, 1.0)
        
        angle = np.arccos(cosine_angle)
        angle_degrees = np.degrees(angle)
        
        return angle_degrees
