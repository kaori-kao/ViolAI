import os
import json
import pickle
import time

class DataManager:
    """
    Class to handle saving and loading of calibration data
    """
    def __init__(self, data_dir="."):
        self.data_dir = data_dir
        self.calibration_file = os.path.join(data_dir, "violin_calibration_data.pickle")
        
    def save_calibration_data(self, calibration_data):
        """
        Save calibration data to a file
        
        Args:
            calibration_data: Dictionary of calibration data
            
        Returns:
            Boolean indicating success
        """
        try:
            # Add timestamp if it doesn't exist
            if "timestamp" not in calibration_data:
                calibration_data["timestamp"] = time.time()
                
            # Save using pickle for preserving numpy arrays and complex structures
            with open(self.calibration_file, 'wb') as f:
                pickle.dump(calibration_data, f)
                
            return True
        except Exception as e:
            print(f"Error saving calibration data: {e}")
            return False
    
    def load_calibration_data(self):
        """
        Load calibration data from a file
        
        Returns:
            Dictionary of calibration data or None if file doesn't exist or error occurs
        """
        if not os.path.exists(self.calibration_file):
            return None
            
        try:
            with open(self.calibration_file, 'rb') as f:
                data = pickle.load(f)
                
            # Verify data structure
            required_keys = ["posture_reference", "bow_positions", "finger_positions", "timestamp"]
            if not all(key in data for key in required_keys):
                print("Calibration data incomplete or corrupted")
                return None
                
            return data
        except Exception as e:
            print(f"Error loading calibration data: {e}")
            return None
    
    def delete_calibration_data(self):
        """
        Delete the calibration data file
        
        Returns:
            Boolean indicating success
        """
        if os.path.exists(self.calibration_file):
            try:
                os.remove(self.calibration_file)
                return True
            except Exception as e:
                print(f"Error deleting calibration data: {e}")
                return False
        return True  # File doesn't exist, so deletion "succeeded"
    
    def get_calibration_age(self):
        """
        Get the age of the calibration data in days
        
        Returns:
            Age in days or None if file doesn't exist
        """
        if not os.path.exists(self.calibration_file):
            return None
            
        try:
            with open(self.calibration_file, 'rb') as f:
                data = pickle.load(f)
                
            if "timestamp" in data:
                age_seconds = time.time() - data["timestamp"]
                age_days = age_seconds / (60 * 60 * 24)
                return age_days
        except Exception:
            pass
            
        return None
