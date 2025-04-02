import cv2
import numpy as np
import time

class Calibrator:
    """
    Class to handle calibration of violin posture and positions
    """
    def __init__(self):
        # Initialize storage for calibration data
        self.posture_reference = None
        self.bow_positions = {
            "frog": None,
            "middle": None,
            "tip": None
        }
        self.finger_positions = {
            "first": None,
            "third": None,
            "high": None
        }
        self.current_landmarks = None
        self.calibration_timestamp = None
        self.calibration_countdown = 0
        self.countdown_start_time = None
        
    def process_calibration(self, frame, landmarks, step, instruction):
        """
        Process a frame for calibration
        
        Args:
            frame: Video frame
            landmarks: MediaPipe pose landmarks
            step: Current calibration step
            instruction: Text instruction for the current step
            
        Returns:
            Tuple of (processed frame, feedback text)
        """
        h, w = frame.shape[:2]
        self.current_landmarks = landmarks
        
        # Display instruction
        cv2.putText(frame, instruction, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        
        # Check if countdown is active
        if self.calibration_countdown > 0:
            # Calculate remaining time
            elapsed = time.time() - self.countdown_start_time
            remaining = max(0, self.calibration_countdown - elapsed)
            
            # Display countdown
            cv2.putText(frame, f"Hold position: {int(remaining)}s", 
                        (int(w/2)-100, int(h/2)), 
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
            
            # Check if countdown finished
            if remaining <= 0:
                self.calibration_countdown = 0
                return frame, "Position captured! You can now continue."
                
            return frame, f"Hold your position. Capturing in {int(remaining)} seconds..."
        
        # No countdown active, display regular instructions
        feedback = "Stand in position and press 'Capture Position' when ready."
        
        return frame, feedback
    
    def save_position(self, step):
        """
        Save the current position for calibration
        
        Args:
            step: Current calibration step
            
        Returns:
            Boolean indicating success
        """
        if not self.current_landmarks:
            return False
            
        # Start a 3-second countdown if not already active
        if self.calibration_countdown == 0:
            self.calibration_countdown = 3
            self.countdown_start_time = time.time()
            return False
            
        # Check if countdown is still active
        if self.calibration_countdown > 0:
            elapsed = time.time() - self.countdown_start_time
            if elapsed < self.calibration_countdown:
                return False
            
        # Countdown finished, store the position based on step
        if step == 0:
            # Store posture reference
            self.posture_reference = self._extract_posture_data(self.current_landmarks)
        elif step == 1:
            # Bow position - frog
            self.bow_positions["frog"] = self._extract_bow_position(self.current_landmarks)
        elif step == 2:
            # Bow position - middle
            self.bow_positions["middle"] = self._extract_bow_position(self.current_landmarks)
        elif step == 3:
            # Bow position - tip
            self.bow_positions["tip"] = self._extract_bow_position(self.current_landmarks)
        elif step == 4:
            # Finger position - 1st
            self.finger_positions["first"] = self._extract_finger_position(self.current_landmarks)
        elif step == 5:
            # Finger position - 3rd
            self.finger_positions["third"] = self._extract_finger_position(self.current_landmarks)
        elif step == 6:
            # Finger position - high
            self.finger_positions["high"] = self._extract_finger_position(self.current_landmarks)
        
        # Reset countdown
        self.calibration_countdown = 0
        self.calibration_timestamp = time.time()
        
        return True
    
    def _extract_posture_data(self, landmarks):
        """
        Extract posture data from landmarks
        
        Args:
            landmarks: MediaPipe pose landmarks
            
        Returns:
            Dictionary of posture data
        """
        posture = {}
        
        # Key landmark indices for posture
        posture_landmarks = [
            0,   # nose
            11,  # left shoulder
            12,  # right shoulder
            23,  # left hip
            24,  # right hip
            13,  # left elbow
            14,  # right elbow
            15,  # left wrist
            16   # right wrist
        ]
        
        for idx in posture_landmarks:
            landmark = landmarks.landmark[idx]
            posture[idx] = (landmark.x, landmark.y, landmark.z)
            
        # Also store relative angles for shoulders and back
        # Left shoulder angle (between left elbow, left shoulder, and left hip)
        left_shoulder_angle = self._calculate_angle(
            landmarks.landmark[13],  # left elbow
            landmarks.landmark[11],  # left shoulder
            landmarks.landmark[23]   # left hip
        )
        
        # Right shoulder angle (between right elbow, right shoulder, and right hip)
        right_shoulder_angle = self._calculate_angle(
            landmarks.landmark[14],  # right elbow
            landmarks.landmark[12],  # right shoulder
            landmarks.landmark[24]   # right hip
        )
        
        # Back angle (between shoulders and hips)
        back_angle = self._calculate_angle(
            landmarks.landmark[11],  # left shoulder
            landmarks.landmark[0],   # nose
            landmarks.landmark[23]   # left hip
        )
        
        posture["angles"] = {
            "left_shoulder": left_shoulder_angle,
            "right_shoulder": right_shoulder_angle,
            "back": back_angle
        }
        
        return posture
    
    def _extract_bow_position(self, landmarks):
        """
        Extract bow position data from landmarks
        
        Args:
            landmarks: MediaPipe pose landmarks
            
        Returns:
            Dictionary of bow position data
        """
        bow_data = {}
        
        # Key landmark indices for bow position
        bow_landmarks = [
            14,  # right elbow
            12,  # right shoulder
            16   # right wrist
        ]
        
        for idx in bow_landmarks:
            landmark = landmarks.landmark[idx]
            bow_data[idx] = (landmark.x, landmark.y, landmark.z)
            
        # Calculate right elbow angle
        elbow_angle = self._calculate_angle(
            landmarks.landmark[12],  # right shoulder
            landmarks.landmark[14],  # right elbow
            landmarks.landmark[16]   # right wrist
        )
        
        bow_data["elbow_angle"] = elbow_angle
        
        return bow_data
    
    def _extract_finger_position(self, landmarks):
        """
        Extract finger position data from landmarks
        
        Args:
            landmarks: MediaPipe pose landmarks
            
        Returns:
            Dictionary of finger position data
        """
        finger_data = {}
        
        # Key landmark indices for finger position
        # Using left hand landmarks (MediaPipe doesn't have detailed finger tracking in the pose model)
        finger_landmarks = [
            13,  # left elbow
            11,  # left shoulder
            15   # left wrist
        ]
        
        for idx in finger_landmarks:
            landmark = landmarks.landmark[idx]
            finger_data[idx] = (landmark.x, landmark.y, landmark.z)
            
        return finger_data
    
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
    
    def get_calibration_data(self):
        """
        Get all calibration data as a dictionary
        
        Returns:
            Dictionary of all calibration data
        """
        return {
            "posture_reference": self.posture_reference,
            "bow_positions": self.bow_positions,
            "finger_positions": self.finger_positions,
            "timestamp": self.calibration_timestamp
        }
    
    def set_calibration_data(self, data):
        """
        Set calibration data from a dictionary
        
        Args:
            data: Dictionary of calibration data
        """
        self.posture_reference = data.get("posture_reference")
        self.bow_positions = data.get("bow_positions")
        self.finger_positions = data.get("finger_positions")
        self.calibration_timestamp = data.get("timestamp")
