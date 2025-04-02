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
        # Enhanced model configuration for better accuracy
        self.pose = self.mp_pose.Pose(
            static_image_mode=False,
            model_complexity=2,  # Use the most complex (accurate) model
            smooth_landmarks=True,  # Enable landmark smoothing
            enable_segmentation=False,
            min_detection_confidence=0.7,  # Higher threshold for more reliable detection
            min_tracking_confidence=0.7    # Higher threshold for more stable tracking
        )
        
    def process_frame(self, frame):
        """
        Process a video frame with MediaPipe Pose
        
        Args:
            frame: Input video frame
            
        Returns:
            Tuple of (processed frame with drawings, landmarks if found)
        """
        # Check if frame is valid
        if frame is None or frame.size == 0:
            return frame, None
            
        # Resize for better performance while maintaining aspect ratio
        h, w = frame.shape[:2]
        if max(w, h) > 1280:  # Limit maximum dimension for better performance
            scale = 1280 / max(w, h)
            new_w, new_h = int(w * scale), int(h * scale)
            frame = cv2.resize(frame, (new_w, new_h))
        
        # Convert the BGR image to RGB
        image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Process the image and get pose landmarks
        results = self.pose.process(image_rgb)
        
        # Draw the pose annotations on the image if landmarks are detected
        if results.pose_landmarks:
            # Enhanced visualization
            self.mp_drawing.draw_landmarks(
                frame,
                results.pose_landmarks,
                self.mp_pose.POSE_CONNECTIONS,
                landmark_drawing_spec=self.mp_drawing_styles.get_default_pose_landmarks_style()
            )
            
            # Draw right arm with thicker lines for better visibility of bowing arm
            landmarks = results.pose_landmarks.landmark
            h, w, _ = frame.shape
            
            # Right shoulder to right elbow (key for bow tracking)
            right_shoulder = (int(landmarks[12].x * w), int(landmarks[12].y * h))
            right_elbow = (int(landmarks[14].x * w), int(landmarks[14].y * h))
            right_wrist = (int(landmarks[16].x * w), int(landmarks[16].y * h))
            
            cv2.line(frame, right_shoulder, right_elbow, (0, 255, 0), 3)  # Green, thicker line
            cv2.line(frame, right_elbow, right_wrist, (0, 255, 0), 3)     # Green, thicker line
            
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
