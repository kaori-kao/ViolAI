import numpy as np
from utils.angle_calculator import AngleCalculator

class PostureAnalyzer:
    """
    Class to analyze violin posture compared to calibrated reference
    """
    def __init__(self):
        self.angle_calculator = AngleCalculator()
        self.threshold_degrees = 15  # Threshold for posture deviation in degrees
        self.posture_history = []
        self.max_history = 10  # For smoothing posture assessment
        
    def analyze_posture(self, landmarks, reference_posture):
        """
        Compare current posture to reference and provide feedback
        
        Args:
            landmarks: MediaPipe pose landmarks
            reference_posture: Calibrated reference posture data
            
        Returns:
            Tuple of (posture status string, detailed feedback)
        """
        if not landmarks or not reference_posture:
            return "Not available", "Reference posture not calibrated or landmarks not detected."
            
        # Calculate current posture angles
        current_angles = self.angle_calculator.calculate_posture_angles(landmarks)
        
        if not current_angles:
            return "Not available", "Could not calculate current posture angles."
            
        # Compare with reference angles
        ref_angles = reference_posture.get("angles", {})
        
        feedback = []
        deviations = []
        
        # Check back angle
        if "back_vertical" in current_angles and "back" in ref_angles:
            back_diff = abs(current_angles["back_vertical"] - ref_angles["back"])
            if back_diff > self.threshold_degrees:
                feedback.append(f"Straighten your back (off by {back_diff:.1f}°)")
                deviations.append(back_diff)
                
        # Check shoulder angles
        if "left_shoulder" in current_angles and "left_shoulder" in ref_angles:
            left_diff = abs(current_angles["left_shoulder"] - ref_angles["left_shoulder"])
            if left_diff > self.threshold_degrees:
                feedback.append(f"Adjust left shoulder position (off by {left_diff:.1f}°)")
                deviations.append(left_diff)
                
        if "right_shoulder" in current_angles and "right_shoulder" in ref_angles:
            right_diff = abs(current_angles["right_shoulder"] - ref_angles["right_shoulder"])
            if right_diff > self.threshold_degrees:
                feedback.append(f"Adjust right shoulder position (off by {right_diff:.1f}°)")
                deviations.append(right_diff)
                
        # Check neck/head position
        if "neck" in current_angles and "back" in ref_angles:  # Use back angle as reference
            neck_diff = abs(current_angles["neck"] - ref_angles["back"])
            if neck_diff > self.threshold_degrees:
                feedback.append(f"Adjust head position (off by {neck_diff:.1f}°)")
                deviations.append(neck_diff)
                
        # Determine overall posture status
        if deviations:
            max_deviation = max(deviations)
            if max_deviation > self.threshold_degrees * 2:
                status = "Poor"
            elif max_deviation > self.threshold_degrees:
                status = "Needs adjustment"
            else:
                status = "Good"
        else:
            status = "Good"
            
        # Add to history for smoothing
        self.posture_history.append(status)
        if len(self.posture_history) > self.max_history:
            self.posture_history.pop(0)
            
        # Get smoothed status (most common in history)
        if self.posture_history:
            status_counts = {}
            for s in self.posture_history:
                status_counts[s] = status_counts.get(s, 0) + 1
                
            smoothed_status = max(status_counts.items(), key=lambda x: x[1])[0]
        else:
            smoothed_status = status
            
        # Format feedback
        if not feedback:
            feedback_text = "Posture looks good. Maintain this position."
        else:
            feedback_text = "Posture feedback: " + " | ".join(feedback)
            
        return smoothed_status, feedback_text
    
    def check_specific_posture_elements(self, landmarks, reference_posture):
        """
        Check specific elements of posture for detailed feedback
        
        Args:
            landmarks: MediaPipe pose landmarks
            reference_posture: Calibrated reference posture data
            
        Returns:
            Dictionary of posture elements with status
        """
        if not landmarks or not reference_posture:
            return {}
            
        elements = {}
        
        # Check shoulder alignment
        left_shoulder = landmarks.landmark[11]
        right_shoulder = landmarks.landmark[12]
        
        ref_left_shoulder = reference_posture.get(11)
        ref_right_shoulder = reference_posture.get(12)
        
        if ref_left_shoulder and ref_right_shoulder:
            # Check if shoulders are level
            current_diff = left_shoulder.y - right_shoulder.y
            ref_diff = ref_left_shoulder[1] - ref_right_shoulder[1]
            
            if abs(current_diff - ref_diff) > 0.05:  # Threshold for shoulder level
                elements["shoulders"] = "Uneven"
            else:
                elements["shoulders"] = "Good"
                
        # Check violin position (based on left wrist)
        left_wrist = landmarks.landmark[15]
        ref_left_wrist = reference_posture.get(15)
        
        if ref_left_wrist:
            # Check if violin position is correct
            position_diff = np.sqrt(
                (left_wrist.x - ref_left_wrist[0])**2 + 
                (left_wrist.y - ref_left_wrist[1])**2
            )
            
            if position_diff > 0.1:  # Threshold for violin position
                elements["violin_position"] = "Needs adjustment"
            else:
                elements["violin_position"] = "Good"
                
        return elements
