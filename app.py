import streamlit as st
import cv2
import threading
import time
import numpy as np
from PIL import Image
import mediapipe as mp
from utils.pose_tracking import PoseTracker
from utils.calibration import Calibrator
from utils.data_manager import DataManager
from utils.bow_direction import BowDirectionDetector
from utils.posture_analyzer import PostureAnalyzer
from utils.rhythm_trainer import RhythmTrainer

# Set page config
st.set_page_config(
    page_title="Violin Coach",
    page_icon="🎻",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Initialize session state variables
if 'calibration_complete' not in st.session_state:
    st.session_state.calibration_complete = False
if 'mode' not in st.session_state:
    st.session_state.mode = "calibration"
if 'frame_count' not in st.session_state:
    st.session_state.frame_count = 0
if 'stop_camera' not in st.session_state:
    st.session_state.stop_camera = False
if 'data_manager' not in st.session_state:
    st.session_state.data_manager = DataManager()
if 'calibrator' not in st.session_state:
    st.session_state.calibrator = Calibrator()
if 'pose_tracker' not in st.session_state:
    st.session_state.pose_tracker = PoseTracker()
if 'bow_detector' not in st.session_state:
    st.session_state.bow_detector = BowDirectionDetector()
if 'posture_analyzer' not in st.session_state:
    st.session_state.posture_analyzer = PostureAnalyzer()
if 'rhythm_trainer' not in st.session_state:
    st.session_state.rhythm_trainer = RhythmTrainer()
if 'camera_started' not in st.session_state:
    st.session_state.camera_started = False
if 'calibration_step' not in st.session_state:
    st.session_state.calibration_step = 0
if 'calibration_steps' not in st.session_state:
    st.session_state.calibration_steps = [
        "Stand in proper posture",
        "Bow position - frog",
        "Bow position - middle",
        "Bow position - tip",
        "Finger position - 1st position",
        "Finger position - 3rd position",
        "Finger position - high position"
    ]
if 'feedback' not in st.session_state:
    st.session_state.feedback = ""
if 'posture_status' not in st.session_state:
    st.session_state.posture_status = "N/A"
if 'bow_direction' not in st.session_state:
    st.session_state.bow_direction = "N/A"
if 'rhythm_progress' not in st.session_state:
    st.session_state.rhythm_progress = 0

# Try to load previous calibration data
try:
    if st.session_state.data_manager.load_calibration_data():
        st.session_state.calibration_complete = True
        st.session_state.mode = "tracking"
except Exception as e:
    st.error(f"Error loading previous calibration data: {e}")

# Function to process video frames in a separate thread
def process_frames(cap, stframe):
    while cap.isOpened() and not st.session_state.stop_camera:
        ret, frame = cap.read()
        if not ret:
            continue
            
        # Flip frame horizontally for a more intuitive mirror view
        frame = cv2.flip(frame, 1)
        
        # Process frame with MediaPipe pose tracking
        frame, landmarks = st.session_state.pose_tracker.process_frame(frame)
        
        if landmarks:
            st.session_state.frame_count += 1
            
            if st.session_state.mode == "calibration":
                # Process calibration
                instruction = st.session_state.calibration_steps[st.session_state.calibration_step]
                frame, feedback = st.session_state.calibrator.process_calibration(
                    frame, landmarks, st.session_state.calibration_step, instruction
                )
                st.session_state.feedback = feedback
                
            elif st.session_state.mode == "tracking":
                # Process tracking and feedback
                bow_direction, elbow_angle = st.session_state.bow_detector.detect_bow_direction(landmarks, frame)
                posture_status, posture_feedback = st.session_state.posture_analyzer.analyze_posture(
                    landmarks, st.session_state.calibrator.posture_reference
                )
                
                rhythm_status, rhythm_progress = st.session_state.rhythm_trainer.update_progress(bow_direction)
                
                # Update session state with current values
                st.session_state.bow_direction = bow_direction
                st.session_state.posture_status = posture_status
                st.session_state.rhythm_progress = rhythm_progress
                st.session_state.feedback = f"{posture_feedback}\n{rhythm_status}"
                
                # Draw feedback on frame
                frame = draw_feedback_on_frame(frame, bow_direction, posture_status, rhythm_progress)
        
        # Convert color space from BGR to RGB
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        stframe.image(frame_rgb, channels="RGB", use_column_width=True)
        
        # Control frame rate
        time.sleep(0.03)  # ~30 fps

    # Release resources
    cap.release()

def draw_feedback_on_frame(frame, bow_direction, posture_status, rhythm_progress):
    """Draw feedback information on the video frame"""
    h, w = frame.shape[:2]
    
    # Draw bow direction indicator
    direction_color = (0, 255, 0) if bow_direction == "Up bow" else (0, 0, 255)  # Green for up bow, Red for down bow
    cv2.putText(frame, f"Bow: {bow_direction}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, direction_color, 2)
    
    # Draw posture indicator
    posture_color = (0, 255, 0) if posture_status == "Good" else (0, 0, 255)  # Green for good, Red for needs adjustment
    cv2.putText(frame, f"Posture: {posture_status}", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, posture_color, 2)
    
    # Draw rhythm progress bar
    bar_width = int(w * 0.8)
    bar_height = 20
    bar_x = int(w * 0.1)
    bar_y = h - 40
    # Background
    cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_width, bar_y + bar_height), (200, 200, 200), -1)
    # Progress
    progress_width = int(bar_width * (rhythm_progress / 32))
    cv2.rectangle(frame, (bar_x, bar_y), (bar_x + progress_width, bar_y + bar_height), (0, 255, 0), -1)
    # Border
    cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_width, bar_y + bar_height), (0, 0, 0), 1)
    # Text
    cv2.putText(frame, f"Progress: {rhythm_progress}/32", (bar_x, bar_y - 10), 
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 1)
    
    return frame

def start_camera():
    """Start the camera and processing thread"""
    if st.session_state.camera_started:
        return
    
    try:
        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            st.error("Error: Could not open camera.")
            return
        
        st.session_state.stop_camera = False
        st.session_state.camera_started = True
        
        # Create a placeholder for the video feed
        stframe = st.empty()
        
        # Start processing in a separate thread
        thread = threading.Thread(target=process_frames, args=(cap, stframe))
        thread.daemon = True
        thread.start()
        
    except Exception as e:
        st.error(f"Error starting camera: {e}")

def stop_camera():
    """Stop the camera and processing thread"""
    if st.session_state.camera_started:
        st.session_state.stop_camera = True
        st.session_state.camera_started = False
        time.sleep(0.5)  # Give time for the thread to exit cleanly

def reset_calibration():
    """Reset all calibration data"""
    stop_camera()
    st.session_state.calibration_complete = False
    st.session_state.calibration_step = 0
    st.session_state.mode = "calibration"
    st.session_state.calibrator = Calibrator()
    st.session_state.data_manager.delete_calibration_data()
    st.info("Calibration data has been reset. Please recalibrate.")
    st.rerun()

def capture_current_position():
    """Capture the current position for calibration"""
    if st.session_state.calibration_step < len(st.session_state.calibration_steps):
        if st.session_state.calibrator.save_position(st.session_state.calibration_step):
            st.session_state.calibration_step += 1
            
            # Check if calibration is complete
            if st.session_state.calibration_step >= len(st.session_state.calibration_steps):
                # Save calibration data
                calibration_data = st.session_state.calibrator.get_calibration_data()
                st.session_state.data_manager.save_calibration_data(calibration_data)
                st.session_state.calibration_complete = True
                st.session_state.mode = "tracking"
                st.success("Calibration complete! The system is now ready to track your performance.")
        else:
            st.warning("Failed to capture position. Please try again.")
    else:
        st.info("All positions have been calibrated.")

# Main application layout
st.title("🎻 Violin Coach")

if st.session_state.mode == "calibration":
    st.subheader("Calibration Mode")
    
    # Display current calibration step
    if st.session_state.calibration_step < len(st.session_state.calibration_steps):
        current_step = st.session_state.calibration_steps[st.session_state.calibration_step]
        st.info(f"Step {st.session_state.calibration_step + 1}/{len(st.session_state.calibration_steps)}: {current_step}")
        
        # Instructions
        if st.session_state.calibration_step == 0:
            st.markdown("""
            ### Stand in proper posture
            - Stand tall with shoulders relaxed
            - Hold your violin in proper playing position
            - Make sure your back is straight
            - Face the camera directly
            """)
        elif st.session_state.calibration_step in [1, 2, 3]:
            positions = ["frog (near the hand)", "middle", "tip (farthest from hand)"]
            st.markdown(f"""
            ### Bow position - {positions[st.session_state.calibration_step - 1]}
            - Hold your bow at the {positions[st.session_state.calibration_step - 1]} position
            - Maintain proper posture
            - Wait for the system to capture this position
            """)
        elif st.session_state.calibration_step in [4, 5, 6]:
            positions = ["1st (closest to scroll)", "3rd (middle)", "high (closest to bridge)"]
            st.markdown(f"""
            ### Finger position - {positions[st.session_state.calibration_step - 4]}
            - Place your fingers in {positions[st.session_state.calibration_step - 4]} position
            - Maintain proper hand and arm posture
            - Wait for the system to capture this position
            """)
    else:
        st.success("All positions have been calibrated!")
        
    # Calibration controls
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if not st.session_state.camera_started:
            if st.button("Start Camera", key="start_cal", use_container_width=True):
                start_camera()
        else:
            if st.button("Stop Camera", key="stop_cal", use_container_width=True):
                stop_camera()
                
    with col2:
        if st.session_state.camera_started and st.session_state.calibration_step < len(st.session_state.calibration_steps):
            if st.button("Capture Position", key="capture", use_container_width=True):
                capture_current_position()
                
    with col3:
        if st.button("Reset Calibration", key="reset_cal", use_container_width=True):
            reset_calibration()
            
    # Feedback area
    st.text_area("Feedback", value=st.session_state.feedback, height=100, disabled=True)
    
else:  # Tracking mode
    st.subheader("Performance Tracking")
    
    # Display status indicators
    col1, col2, col3 = st.columns(3)
    
    with col1:
        bow_color = "green" if st.session_state.bow_direction in ["Up bow", "Down bow"] else "gray"
        st.markdown(f"<p style='font-size:20px'>Bow Direction: <span style='color:{bow_color};font-weight:bold'>{st.session_state.bow_direction}</span></p>", unsafe_allow_html=True)
        
    with col2:
        posture_color = "green" if st.session_state.posture_status == "Good" else "red"
        st.markdown(f"<p style='font-size:20px'>Posture: <span style='color:{posture_color};font-weight:bold'>{st.session_state.posture_status}</span></p>", unsafe_allow_html=True)
        
    with col3:
        progress_color = "green" if st.session_state.rhythm_progress > 0 else "gray"
        st.markdown(f"<p style='font-size:20px'>Progress: <span style='color:{progress_color};font-weight:bold'>{st.session_state.rhythm_progress}/32</span></p>", unsafe_allow_html=True)
    
    # Progress bar for rhythm training
    st.progress(st.session_state.rhythm_progress / 32)
    
    # Controls
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        if not st.session_state.camera_started:
            if st.button("Start Tracking", key="start_track", use_container_width=True):
                start_camera()
        else:
            if st.button("Stop Tracking", key="stop_track", use_container_width=True):
                stop_camera()
                
    with col2:
        if st.button("Reset Progress", key="reset_progress", use_container_width=True):
            st.session_state.rhythm_trainer.reset_progress()
            st.session_state.rhythm_progress = 0
            st.rerun()
            
    with col3:
        if st.button("Recalibrate", key="recalibrate", use_container_width=True):
            stop_camera()
            st.session_state.mode = "calibration"
            st.session_state.calibration_step = 0
            st.session_state.calibration_complete = False
            st.rerun()
            
    with col4:
        if st.button("Reset All", key="reset_all", use_container_width=True):
            reset_calibration()
    
    # Feedback area
    st.text_area("Feedback", value=st.session_state.feedback, height=100, disabled=True)
    
    # Tracking information
    st.markdown("### Twinkle Twinkle Little Star - Bow Pattern")
    st.markdown("""
    The pattern alternates between down bow and up bow movements.
    Follow the pattern as indicated on the screen.
    The system will track your progress through the 32 bow changes.
    """)

# Info section in sidebar
with st.sidebar:
    st.header("Violin Coach - Help")
    st.markdown("""
    ### How to use this app:
    
    1. **Calibration Mode**:
       - Follow the instructions for each calibration step
       - Stand in front of the camera with good lighting
       - Hold each position steady while capturing
    
    2. **Performance Tracking**:
       - The app will track your bow direction based on your right elbow angle
       - Your posture will be compared to your calibrated reference
       - For rhythm training, follow the Twinkle Twinkle pattern
    
    3. **Feedback System**:
       - Green indicators = good
       - Red indicators = needs adjustment
       - Progress bar shows your position in the song
    
    ### Tips for best results:
    - Wear clothing that contrasts with your background
    - Find a well-lit area with minimal background movement
    - Position yourself 3-6 feet from the camera
    - The full upper body should be visible in the frame
    """)

    # Version info
    st.markdown("---")
    st.markdown("Version 1.0")
    st.markdown("© 2023 Violin Coach")

# Start the camera automatically if in tracking mode with calibration complete
if st.session_state.mode == "tracking" and st.session_state.calibration_complete and not st.session_state.camera_started:
    start_camera()
