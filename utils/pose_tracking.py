import cv2
import mediapipe as mp
import numpy as np

class PoseTracker:
    """
    Class to handle pose tracking using MediaPipe
    """
    def __init__(self):
        self.mp_pose = mp.solutions.pose
        self.mp_drawing = mp.solutions.drawing_utils
        self.mp_drawing_styles = mp.solutions.drawing_styles
        self.pose = self.mp_pose.Pose(
            static_image_mode=False,
            model_complexity=2,
            enable_segmentation=False,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
    def process_frame(self, frame):
        """
        Process a video frame with MediaPipe Pose
        
        Args:
            frame: Input video frame
            
        Returns:
            Tuple of (processed frame with drawings, landmarks if found)
        """
        # Convert the BGR image to RGB
        image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Process the image and get pose landmarks
        results = self.pose.process(image_rgb)
        
        # Draw the pose annotations on the image if landmarks are detected
        if results.pose_landmarks:
            self.mp_drawing.draw_landmarks(
                frame,
                results.pose_landmarks,
                self.mp_pose.POSE_CONNECTIONS,
                landmark_drawing_spec=self.mp_drawing_styles.get_default_pose_landmarks_style()
            )
            return frame, results.pose_landmarks
        
        return frame, None
    
    def get_landmark_coordinates(self, landmarks, image_width, image_height):
        """
        Extract 3D coordinates of landmarks
        
        Args:
            landmarks: MediaPipe pose landmarks
            image_width: Width of the image
            image_height: Height of the image
            
        Returns:
            Dictionary of landmark coordinates
        """
        if not landmarks:
            return None
            
        landmark_dict = {}
        for idx, landmark in enumerate(landmarks.landmark):
            # Convert normalized coordinates to pixel coordinates
            x = int(landmark.x * image_width)
            y = int(landmark.y * image_height)
            z = landmark.z  # Keep z as normalized depth
            
            # Store coordinates by landmark index
            landmark_dict[idx] = (x, y, z)
            
        return landmark_dict
