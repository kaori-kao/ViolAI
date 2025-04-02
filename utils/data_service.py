import json
import datetime
from database import (
    create_user, get_user_by_username, create_practice_session, end_practice_session,
    record_practice_event, save_calibration_profile, get_active_calibration_profile,
    get_user_practice_history
)

class DataService:
    """
    Service class to interface between the app and the database
    """
    def __init__(self, username="default_user", email="default@example.com"):
        """
        Initialize the data service with a user
        """
        # Get or create user
        self.user = get_user_by_username(username)
        if not self.user:
            self.user = create_user(username, email)
            
        self.current_session = None
        
    def start_practice_session(self, piece_name="Twinkle Twinkle Little Star"):
        """
        Start a new practice session
        """
        if self.current_session:
            # End current session if one exists
            self.end_practice_session()
            
        self.current_session = create_practice_session(self.user.id, piece_name)
        return self.current_session
    
    def end_practice_session(self, **kwargs):
        """
        End the current practice session with scores
        """
        if self.current_session:
            session_id = self.current_session.id
            self.current_session = end_practice_session(session_id, **kwargs)
            return self.current_session
        return None
    
    def record_event(self, event_type, event_data):
        """
        Record a practice event during the session
        """
        if not self.current_session:
            # Start a new session if none exists
            self.start_practice_session()
            
        # Convert dict to JSON string if needed
        if isinstance(event_data, dict):
            event_data = json.dumps(event_data)
            
        return record_practice_event(self.current_session.id, event_type, event_data)
    
    def record_posture_event(self, posture_status, details=None):
        """
        Record a posture correction event
        """
        event_data = {
            "status": posture_status,
            "details": details or {},
            "timestamp": datetime.datetime.utcnow().isoformat()
        }
        return self.record_event("posture_correction", event_data)
    
    def record_bow_direction_event(self, direction, angle=None):
        """
        Record a bow direction change event
        """
        event_data = {
            "direction": direction,
            "angle": angle,
            "timestamp": datetime.datetime.utcnow().isoformat()
        }
        return self.record_event("bow_direction_change", event_data)
    
    def record_rhythm_progress(self, progress, total=32):
        """
        Record rhythm progress event
        """
        event_data = {
            "progress": progress,
            "total": total,
            "percentage": (progress / total) * 100 if total > 0 else 0,
            "timestamp": datetime.datetime.utcnow().isoformat()
        }
        return self.record_event("rhythm_progress", event_data)
    
    def save_calibration(self, calibration_data, name="Default Profile"):
        """
        Save calibration data to a profile
        """
        # Convert dict to JSON string if needed
        if isinstance(calibration_data, dict):
            calibration_data = json.dumps(calibration_data)
            
        return save_calibration_profile(self.user.id, calibration_data, name)
    
    def get_calibration(self):
        """
        Get the active calibration profile
        """
        profile = get_active_calibration_profile(self.user.id)
        if profile and profile.calibration_data:
            try:
                # Parse JSON string to dict
                return json.loads(profile.calibration_data)
            except:
                return None
        return None
    
    def get_practice_history(self, limit=10):
        """
        Get practice history for the current user
        """
        return get_user_practice_history(self.user.id, limit)
    
    def calculate_session_scores(self, posture_events, bow_events, rhythm_events):
        """
        Calculate scores based on session events
        """
        # Posture score (percentage of good posture)
        total_posture = len(posture_events)
        good_posture = sum(1 for e in posture_events if json.loads(e.event_data)["status"] == "Good")
        posture_score = (good_posture / total_posture * 100) if total_posture > 0 else 0
        
        # Bow direction accuracy
        total_bow = len(bow_events)
        valid_bow = sum(1 for e in bow_events if json.loads(e.event_data)["direction"] in ["Up bow", "Down bow"])
        bow_score = (valid_bow / total_bow * 100) if total_bow > 0 else 0
        
        # Rhythm progress
        rhythm_progress = 0
        if rhythm_events:
            # Get the highest progress value
            rhythm_progress = max(
                [json.loads(e.event_data)["progress"] for e in rhythm_events]
            )
        rhythm_score = (rhythm_progress / 32 * 100)
        
        # Overall score (weighted average)
        overall_score = (posture_score * 0.4 + bow_score * 0.4 + rhythm_score * 0.2)
        
        return {
            "posture_score": posture_score,
            "bow_score": bow_score,
            "rhythm_score": rhythm_score,
            "overall_score": overall_score
        }