import streamlit as st
import cv2
import threading
import time
import numpy as np
from PIL import Image
import mediapipe as mp
import json
import datetime
import os

from utils.pose_tracking import PoseTracker
from utils.calibration import Calibrator
from utils.data_manager import DataManager
from utils.bow_direction import BowDirectionDetector
from utils.posture_analyzer import PostureAnalyzer
from utils.rhythm_trainer import RhythmTrainer
from utils.data_service import DataService

# Set page config
st.set_page_config(
    page_title="Violin Coach",
    page_icon="🎻",
    layout="wide",
    initial_sidebar_state="expanded",
    menu_items={
        'Get Help': 'https://docs.streamlit.io',
        'Report a bug': "https://github.com/your-repo/violin-coach/issues",
        'About': """
        # Violin Coach App
        A computer vision application that helps violin students improve their posture and bowing technique.
        """
    }
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
if 'data_service' not in st.session_state:
    st.session_state.data_service = DataService(username="violin_student")
if 'practice_session' not in st.session_state:
    st.session_state.practice_session = None
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
                
                # Record events to database if we have an active session
                if st.session_state.practice_session is not None:
                    # Only record events every 30 frames (about once per second) to avoid too many database writes
                    if st.session_state.frame_count % 30 == 0:
                        # Record posture event
                        st.session_state.data_service.record_posture_event(
                            posture_status,
                            {"feedback": posture_feedback}
                        )
                        
                        # Record bow direction event
                        if bow_direction in ["Up bow", "Down bow"]:
                            st.session_state.data_service.record_bow_direction_event(
                                bow_direction,
                                angle=elbow_angle
                            )
                        
                        # Record rhythm progress
                        if rhythm_progress > 0:
                            st.session_state.data_service.record_rhythm_progress(
                                rhythm_progress
                            )
        
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
    
    # Add header/title
    cv2.rectangle(frame, (0, 0), (w, 80), (50, 50, 50), -1)  # Dark background for header
    cv2.putText(frame, "Violin Coach", (w//2 - 80, 30), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)
    
    # Draw bow direction indicator with enhanced visibility
    if bow_direction == "Up bow":
        direction_color = (0, 255, 0)  # Green for up bow
        direction_icon = "↑"
    elif bow_direction == "Down bow":
        direction_color = (0, 0, 255)  # Red for down bow
        direction_icon = "↓"
    else:
        direction_color = (200, 200, 200)  # Gray for other states
        direction_icon = "•"
        
    cv2.putText(frame, f"Bow: {bow_direction} {direction_icon}", (10, 110), 
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, direction_color, 2)
    
    # Draw posture indicator with improved visualization
    if posture_status == "Good":
        posture_color = (0, 255, 0)  # Green for good
        posture_emoji = "✓"
    else:
        posture_color = (0, 0, 255)  # Red for needs adjustment
        posture_emoji = "✗"
        
    cv2.putText(frame, f"Posture: {posture_status} {posture_emoji}", (10, 140), 
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, posture_color, 2)
    
    # Draw expected bow direction for next move
    if rhythm_progress < 32:
        expected_direction = "Down bow" if rhythm_progress % 2 == 0 else "Up bow"
        expected_icon = "↓" if expected_direction == "Down bow" else "↑"
        cv2.putText(frame, f"Next: {expected_direction} {expected_icon}", (10, 170),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 165, 0), 2)  # Orange for next move
    
    # Draw rhythm progress bar with improved appearance
    bar_width = int(w * 0.8)
    bar_height = 30
    bar_x = int(w * 0.1)
    bar_y = h - 50
    
    # Background with slightly rounded corners
    cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_width, bar_y + bar_height), (70, 70, 70), -1)
    
    # Progress with gradient colors based on completion
    progress_width = int(bar_width * (rhythm_progress / 32))
    if progress_width > 0:
        # Gradient from blue to green based on progress
        if rhythm_progress < 16:
            progress_color = (255, 128, 0)  # Orange for first half
        else:
            progress_color = (0, 255, 0)    # Green for second half
            
        cv2.rectangle(frame, (bar_x, bar_y), (bar_x + progress_width, bar_y + bar_height), progress_color, -1)
    
    # Border
    cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_width, bar_y + bar_height), (200, 200, 200), 2)
    
    # Text above the progress bar
    cv2.putText(frame, f"Progress: {rhythm_progress}/32 - Twinkle Twinkle Little Star", 
                (bar_x, bar_y - 15), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
    
    return frame

def start_camera():
    """Start the camera and processing thread"""
    if st.session_state.camera_started:
        return
    
    try:
        # Start a practice session in the database
        if st.session_state.mode == "tracking" and st.session_state.practice_session is None:
            st.session_state.practice_session = st.session_state.data_service.start_practice_session()
            st.info(f"Practice session started! Session #{st.session_state.practice_session.id}")
        
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
        
        # End the practice session if in tracking mode
        if st.session_state.mode == "tracking" and st.session_state.practice_session is not None:
            # Calculate scores
            posture_score = 80.0 if st.session_state.posture_status == "Good" else 40.0
            bow_score = 75.0 if st.session_state.bow_direction in ["Up bow", "Down bow"] else 30.0
            rhythm_score = (st.session_state.rhythm_progress / 32) * 100
            overall_score = posture_score * 0.4 + bow_score * 0.4 + rhythm_score * 0.2
            
            # End the session with scores
            st.session_state.data_service.end_practice_session(
                posture_score=posture_score,
                bow_score=bow_score,
                rhythm_score=rhythm_score,
                overall_score=overall_score,
                notes=f"Completed {st.session_state.rhythm_progress}/32 bow changes"
            )
            
            st.success(f"Practice session ended and saved! Overall score: {overall_score:.1f}%")
            st.session_state.practice_session = None

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

# Add tabs for different sections
practice_tab, history_tab, analytics_tab = st.tabs(["Practice", "History", "Analytics"])

# History tab content
with history_tab:
    st.subheader("Practice History")
    
    # Get practice history from database
    if "data_service" in st.session_state:
        history = st.session_state.data_service.get_practice_history(limit=20)
        
        if history and len(history) > 0:
            # Create a DataFrame from the history
            import pandas as pd
            
            history_data = []
            for session in history:
                history_data.append({
                    "Date": session.start_time.strftime("%Y-%m-%d %H:%M"),
                    "Duration (min)": round(session.duration_seconds / 60, 1) if session.duration_seconds else 0,
                    "Piece": session.piece_name,
                    "Posture Score": f"{session.posture_score:.1f}%" if session.posture_score else "N/A",
                    "Bow Score": f"{session.bow_direction_accuracy:.1f}%" if session.bow_direction_accuracy else "N/A",
                    "Rhythm Score": f"{session.rhythm_score:.1f}%" if session.rhythm_score else "N/A",
                    "Overall Score": f"{session.overall_score:.1f}%" if session.overall_score else "N/A",
                    "Notes": session.notes or ""
                })
            
            df = pd.DataFrame(history_data)
            
            # Display the history table
            st.dataframe(df, use_container_width=True)
            
            # Create a line chart of overall scores over time
            if len(history_data) > 1:
                import plotly.express as px
                
                scores_df = pd.DataFrame([{
                    "Date": session.start_time,
                    "Overall Score": session.overall_score,
                    "Posture Score": session.posture_score,
                    "Bow Score": session.bow_direction_accuracy,
                    "Rhythm Score": session.rhythm_score
                } for session in history if session.overall_score])
                
                if not scores_df.empty:
                    st.subheader("Score Progress")
                    fig = px.line(scores_df, x="Date", y=["Overall Score", "Posture Score", "Bow Score", "Rhythm Score"],
                                title="Practice Scores Over Time")
                    fig.update_layout(yaxis_title="Score (%)", xaxis_title="Practice Date")
                    st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No practice history available yet. Start practicing to build your history!")
    else:
        st.warning("Data service not initialized. Please restart the application.")
        
# Analytics tab content
with analytics_tab:
    st.subheader("Performance Analytics")
    
    if "data_service" in st.session_state:
        history = st.session_state.data_service.get_practice_history(limit=50)
        
        if history and len(history) > 0:
            import pandas as pd
            import plotly.express as px
            import plotly.graph_objects as go
            from datetime import datetime, timedelta
            
            # Calculate practice statistics
            total_sessions = len(history)
            total_duration = sum(s.duration_seconds or 0 for s in history) / 60  # in minutes
            avg_duration = total_duration / total_sessions if total_sessions > 0 else 0
            avg_overall_score = sum(s.overall_score or 0 for s in history) / total_sessions if total_sessions > 0 else 0
            
            # Create metrics
            col1, col2, col3, col4 = st.columns(4)
            with col1:
                st.metric("Total Sessions", f"{total_sessions}")
            with col2:
                st.metric("Total Practice Time", f"{total_duration:.1f} min")
            with col3:
                st.metric("Avg. Session Length", f"{avg_duration:.1f} min")
            with col4:
                st.metric("Avg. Overall Score", f"{avg_overall_score:.1f}%")
            
            # Create a heatmap of practice frequency
            if len(history) > 5:
                # Get date range
                end_date = datetime.now()
                start_date = end_date - timedelta(days=30)
                
                # Count sessions per day
                date_counts = {}
                for session in history:
                    date_str = session.start_time.strftime("%Y-%m-%d")
                    date_counts[date_str] = date_counts.get(date_str, 0) + 1
                
                # Create a list of dates for the heatmap
                date_range = pd.date_range(start=start_date, end=end_date)
                practice_data = []
                
                for date in date_range:
                    date_str = date.strftime("%Y-%m-%d")
                    practice_data.append({
                        "Date": date_str,
                        "Weekday": date.strftime("%A"),
                        "Week": date.strftime("%U"),
                        "Count": date_counts.get(date_str, 0)
                    })
                
                practice_df = pd.DataFrame(practice_data)
                
                # Create a heatmap
                st.subheader("Practice Frequency")
                fig = px.density_heatmap(practice_df, x="Date", y="Weekday", z="Count",
                                        title="Practice Sessions Per Day")
                fig.update_layout(xaxis_title="Date", yaxis_title="Day of Week")
                st.plotly_chart(fig, use_container_width=True)
                
                # Score breakdown by component
                st.subheader("Score Breakdown")
                
                avg_posture = sum(s.posture_score or 0 for s in history) / total_sessions if total_sessions > 0 else 0
                avg_bow = sum(s.bow_direction_accuracy or 0 for s in history) / total_sessions if total_sessions > 0 else 0
                avg_rhythm = sum(s.rhythm_score or 0 for s in history) / total_sessions if total_sessions > 0 else 0
                
                # Create a radar chart for score breakdown
                categories = ['Posture', 'Bow Direction', 'Rhythm']
                
                fig = go.Figure()
                
                fig.add_trace(go.Scatterpolar(
                    r=[avg_posture, avg_bow, avg_rhythm],
                    theta=categories,
                    fill='toself',
                    name='Average Scores'
                ))
                
                fig.update_layout(
                    polar=dict(
                        radialaxis=dict(
                            visible=True,
                            range=[0, 100]
                        )
                    ),
                    title="Average Score by Component"
                )
                
                st.plotly_chart(fig, use_container_width=True)
                
                # Progress over time
                st.subheader("Progress Over Time")
                
                # Create a rolling average of scores
                scores_df = pd.DataFrame([{
                    "Date": session.start_time,
                    "Overall Score": session.overall_score
                } for session in history if session.overall_score])
                
                if not scores_df.empty:
                    scores_df = scores_df.sort_values("Date")
                    scores_df["Rolling Average"] = scores_df["Overall Score"].rolling(window=3, min_periods=1).mean()
                    
                    fig = px.line(scores_df, x="Date", y=["Overall Score", "Rolling Average"],
                                title="Score Progression with 3-Session Rolling Average")
                    fig.update_layout(yaxis_title="Score (%)", xaxis_title="Practice Date")
                    st.plotly_chart(fig, use_container_width=True)
                
                # Improvement areas
                st.subheader("Areas for Improvement")
                
                # Identify weakest component
                components = {
                    "Posture": avg_posture,
                    "Bow Direction": avg_bow,
                    "Rhythm": avg_rhythm
                }
                
                weakest = min(components, key=components.get)
                
                st.info(f"Your data suggests that **{weakest}** is your weakest area with an average score of {components[weakest]:.1f}%.")
                
                if weakest == "Posture":
                    st.markdown("""
                    **Practice Tips for Improving Posture:**
                    - Focus on maintaining a straight back and relaxed shoulders
                    - Practice in front of a mirror
                    - Take breaks every 15-20 minutes to reset your posture
                    - Try using a proper violin shoulder rest if you don't already have one
                    """)
                elif weakest == "Bow Direction":
                    st.markdown("""
                    **Practice Tips for Improving Bow Direction:**
                    - Practice slow, deliberate bow movements while watching in a mirror
                    - Focus on keeping your bow parallel to the bridge
                    - Practice string crossings with careful attention to bow angle
                    - Work on maintaining consistent bow pressure
                    """)
                else:  # Rhythm
                    st.markdown("""
                    **Practice Tips for Improving Rhythm:**
                    - Practice with a metronome at a slow tempo
                    - Clap the rhythm before playing
                    - Record yourself and listen for rhythmic accuracy
                    - Work on bow distribution to ensure even note durations
                    """)
        else:
            st.info("Not enough practice data for analytics. Complete a few practice sessions to see insights!")
    else:
        st.warning("Data service not initialized. Please restart the application.")

# Practice tab content
with practice_tab:
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
    st.header("🎻 Violin Coach - Help")
    
    # Add app logo/image
    st.image("violin_image.jpg", width=200)
    
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
       - 🟢 Green indicators = good
       - 🔴 Red indicators = needs adjustment
       - The progress bar shows your position in the song
    
    ### Tips for best results:
    - Wear clothing that contrasts with your background
    - Find a well-lit area with minimal background movement
    - Position yourself 3-6 feet from the camera
    - Make sure your full upper body is visible in the frame
    - Use a plain background for better detection accuracy
    """)
    
    # Add expandable section for advanced tips
    with st.expander("Advanced Tips"):
        st.markdown("""
        - For best posture detection, stand straight with your shoulders aligned
        - When calibrating finger positions, maintain a natural hand position
        - The bow detection works best when your bow arm is clearly visible against the background
        - If detection is unstable, try wearing contrasting colors for better visibility
        - Adjust lighting to reduce shadows on your face and arms
        """)

    # Version info with improved styling
    st.markdown("---")
    st.markdown("<h4 style='text-align: center;'>Violin Coach v2.0</h4>", unsafe_allow_html=True)
    st.markdown("<p style='text-align: center; color: gray;'>© 2025 Violin Coach</p>", unsafe_allow_html=True)

# Start the camera automatically if in tracking mode with calibration complete
if st.session_state.mode == "tracking" and st.session_state.calibration_complete and not st.session_state.camera_started:
    start_camera()
