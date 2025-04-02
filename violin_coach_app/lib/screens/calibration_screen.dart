import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:convert';

import '../services/database_helper.dart';
import '../services/pose_detector_service.dart';

class CalibrationScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const CalibrationScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _CalibrationScreenState createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  
  // Services
  final PoseDetectorService _poseDetector = PoseDetectorService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Calibration state
  int _currentStep = 0;
  bool _isCapturing = false;
  final Map<String, dynamic> _calibrationData = {};
  int? _currentUserId;
  
  // Calibration steps
  final List<Map<String, dynamic>> _calibrationSteps = [
    {
      'title': 'Ready Position',
      'description': 'Stand in your normal playing position with the violin properly positioned under your chin.',
      'instruction': 'Look straight ahead and keep your back straight.',
    },
    {
      'title': 'Bow Hold',
      'description': 'Hold your bow with proper technique, resting on the strings in the middle of the bow.',
      'instruction': 'Maintain a relaxed grip, with curved fingers and flexible wrist.',
    },
    {
      'title': 'Right Arm Down Bow',
      'description': 'Position your right arm for a down bow (from frog to tip).',
      'instruction': 'Your elbow should be at approximately the same height as your wrist.',
    },
    {
      'title': 'Right Arm Up Bow',
      'description': 'Position your right arm for an up bow (from tip to frog).',
      'instruction': 'Keep your elbow slightly raised and wrist flexible.',
    },
    {
      'title': 'Left Hand Position',
      'description': 'Position your left hand in first position on the fingerboard.',
      'instruction': 'Thumb should be relaxed on the side of the neck, with curved fingers above the strings.',
    },
  ];
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeUser();
  }
  
  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }
  
  /// Initialize the camera and pose detector
  Future<void> _initializeCamera() async {
    final cameras = widget.cameras;
    if (cameras.isEmpty) {
      _showSnackBar('No camera available');
      return;
    }
    
    // Use the first camera
    final camera = cameras.first;
    
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    
    try {
      await _cameraController!.initialize();
      await _poseDetector.initialize();
      
      setState(() {
        _isCameraInitialized = true;
      });
      
      // Start camera stream
      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      _showSnackBar('Error initializing camera: $e');
    }
  }
  
  /// Stop the camera
  void _stopCamera() {
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
      }
      _cameraController!.dispose();
      _cameraController = null;
      
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }
  
  /// Initialize user
  Future<void> _initializeUser() async {
    try {
      // Get or create default user
      final user = await _dbHelper.getUserByUsername('default_user');
      if (user != null) {
        setState(() {
          _currentUserId = user['id'] as int;
        });
      }
    } catch (e) {
      _showSnackBar('Error loading user data: $e');
    }
  }
  
  /// Process camera image and detect pose
  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || !_isCapturing) return;
    
    _isDetecting = true;
    
    try {
      final result = await _poseDetector.processFrame(image);
      
      if (result.containsKey('error')) {
        // Handle error
        _isDetecting = false;
        return;
      }
      
      final keypoints3D = result['keypoints3D'] as List<List<double>>;
      final confidences = result['confidences'] as List<double>;
      
      // Process keypoints for calibration
      if (_isCapturing) {
        _captureCalibrationData(keypoints3D, confidences);
      }
    } catch (e) {
      print('Error processing frame: $e');
    } finally {
      _isDetecting = false;
    }
  }
  
  /// Capture calibration data for the current step
  void _captureCalibrationData(List<List<double>> keypoints, List<double> confidences) {
    // Extract relevant data based on current step
    Map<String, dynamic> stepData = {};
    
    switch (_currentStep) {
      case 0: // Ready Position
        stepData = _extractPostureData(keypoints, confidences);
        break;
      case 1: // Bow Hold
        stepData = _extractBowHoldData(keypoints, confidences);
        break;
      case 2: // Down Bow
        stepData = _extractDownBowData(keypoints, confidences);
        break;
      case 3: // Up Bow
        stepData = _extractUpBowData(keypoints, confidences);
        break;
      case 4: // Left Hand Position
        stepData = _extractLeftHandData(keypoints, confidences);
        break;
    }
    
    // Update calibration data
    _calibrationData['step_${_currentStep}'] = stepData;
    
    // Stop capturing
    setState(() {
      _isCapturing = false;
    });
    
    _showSnackBar('Position captured!');
  }
  
  /// Extract posture data from keypoints
  Map<String, dynamic> _extractPostureData(List<List<double>> keypoints, List<double> confidences) {
    // Define index mapping for body parts
    // These should match the TCPformer model output
    const int nose = 0;
    const int neck = 1;
    const int rightShoulder = 2;
    const int leftShoulder = 5;
    
    // Calculate key angles and positions for posture
    final neckAngle = _calculateAngle(
      keypoints[nose],
      keypoints[neck],
      [keypoints[neck][0], keypoints[neck][1] + 100, keypoints[neck][2]], // Vertical down
    );
    
    final shoulderAlignment = _calculateHorizontalAngle(
      keypoints[leftShoulder],
      keypoints[rightShoulder],
    );
    
    return {
      'posture': {
        'neck_angle': neckAngle,
        'shoulder_alignment': shoulderAlignment,
        'head_position': keypoints[nose],
        'left_shoulder': keypoints[leftShoulder],
        'right_shoulder': keypoints[rightShoulder],
        'confident': confidences[nose] > 0.7 && 
                    confidences[neck] > 0.7 && 
                    confidences[rightShoulder] > 0.7 &&
                    confidences[leftShoulder] > 0.7,
      }
    };
  }
  
  /// Extract bow hold data from keypoints
  Map<String, dynamic> _extractBowHoldData(List<List<double>> keypoints, List<double> confidences) {
    // Define index mapping for body parts
    const int rightWrist = 4;
    const int rightElbow = 3;
    
    return {
      'bow_hold': {
        'right_wrist': keypoints[rightWrist],
        'right_elbow': keypoints[rightElbow],
        'wrist_height': keypoints[rightWrist][1],
        'confident': confidences[rightWrist] > 0.7 && confidences[rightElbow] > 0.7,
      }
    };
  }
  
  /// Extract down bow data from keypoints
  Map<String, dynamic> _extractDownBowData(List<List<double>> keypoints, List<double> confidences) {
    // Define index mapping for body parts
    const int rightShoulder = 2;
    const int rightElbow = 3;
    const int rightWrist = 4;
    
    final elbowAngle = _calculateAngle(
      keypoints[rightShoulder],
      keypoints[rightElbow],
      keypoints[rightWrist],
    );
    
    return {
      'down_bow': {
        'right_shoulder': keypoints[rightShoulder],
        'right_elbow': keypoints[rightElbow],
        'right_wrist': keypoints[rightWrist],
        'elbow_angle': elbowAngle,
        'confident': confidences[rightShoulder] > 0.7 && 
                    confidences[rightElbow] > 0.7 && 
                    confidences[rightWrist] > 0.7,
      }
    };
  }
  
  /// Extract up bow data from keypoints
  Map<String, dynamic> _extractUpBowData(List<List<double>> keypoints, List<double> confidences) {
    // Define index mapping for body parts
    const int rightShoulder = 2;
    const int rightElbow = 3;
    const int rightWrist = 4;
    
    final elbowAngle = _calculateAngle(
      keypoints[rightShoulder],
      keypoints[rightElbow],
      keypoints[rightWrist],
    );
    
    return {
      'up_bow': {
        'right_shoulder': keypoints[rightShoulder],
        'right_elbow': keypoints[rightElbow],
        'right_wrist': keypoints[rightWrist],
        'elbow_angle': elbowAngle,
        'confident': confidences[rightShoulder] > 0.7 && 
                    confidences[rightElbow] > 0.7 && 
                    confidences[rightWrist] > 0.7,
      }
    };
  }
  
  /// Extract left hand data from keypoints
  Map<String, dynamic> _extractLeftHandData(List<List<double>> keypoints, List<double> confidences) {
    // Define index mapping for body parts
    const int leftShoulder = 5;
    const int leftElbow = 6;
    const int leftWrist = 7;
    
    final elbowAngle = _calculateAngle(
      keypoints[leftShoulder],
      keypoints[leftElbow],
      keypoints[leftWrist],
    );
    
    return {
      'left_hand': {
        'left_shoulder': keypoints[leftShoulder],
        'left_elbow': keypoints[leftElbow],
        'left_wrist': keypoints[leftWrist],
        'elbow_angle': elbowAngle,
        'left_elbow_height': keypoints[leftElbow][1],
        'confident': confidences[leftShoulder] > 0.7 && 
                    confidences[leftElbow] > 0.7 && 
                    confidences[leftWrist] > 0.7,
      }
    };
  }
  
  /// Calculate the angle between three 3D points
  double _calculateAngle(List<double> a, List<double> b, List<double> c) {
    // This function can be the same as in PoseDetectorService
    
    // Vectors from point b to a and b to c
    final ba = [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
    final bc = [c[0] - b[0], c[1] - b[1], c[2] - b[2]];
    
    // Dot product
    final dotProduct = ba[0] * bc[0] + ba[1] * bc[1] + ba[2] * bc[2];
    
    // Magnitudes
    final magnitudeBA = _magnitude(ba);
    final magnitudeBC = _magnitude(bc);
    
    // Angle in radians
    final angle = Math.acos(dotProduct / (magnitudeBA * magnitudeBC));
    
    // Convert to degrees
    return angle * 180 / Math.pi;
  }
  
  /// Calculate magnitude of a 3D vector
  double _magnitude(List<double> vector) {
    return Math.sqrt(vector[0] * vector[0] + vector[1] * vector[1] + vector[2] * vector[2]);
  }
  
  /// Calculate horizontal angle from the x-axis
  double _calculateHorizontalAngle(List<double> a, List<double> b) {
    // Vector from a to b
    final ab = [b[0] - a[0], b[1] - a[1]];
    
    // Reference horizontal vector
    final horizontal = [1.0, 0.0];
    
    // Dot product
    final dotProduct = ab[0] * horizontal[0] + ab[1] * horizontal[1];
    
    // Magnitudes
    final magnitudeAB = Math.sqrt(ab[0] * ab[0] + ab[1] * ab[1]);
    final magnitudeH = 1.0; // Unit vector
    
    // Angle in radians
    final angle = Math.acos(dotProduct / (magnitudeAB * magnitudeH));
    
    // Convert to degrees
    return angle * 180 / Math.pi;
  }
  
  /// Capture current position for the current step
  void _capturePosition() {
    if (_isCapturing) return;
    
    setState(() {
      _isCapturing = true;
    });
    
    _showSnackBar('Capturing position...');
  }
  
  /// Move to the next calibration step
  void _nextStep() {
    if (_currentStep < _calibrationSteps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _completeCalibration();
    }
  }
  
  /// Move to the previous calibration step
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }
  
  /// Complete the calibration process
  void _completeCalibration() async {
    if (_currentUserId == null) {
      _showSnackBar('User not initialized');
      return;
    }
    
    try {
      // Save the calibration data to the database
      final calibrationJson = json.encode(_calibrationData);
      
      await _dbHelper.saveCalibrationProfile(
        _currentUserId!,
        calibrationJson,
        name: 'Profile ${DateTime.now().toString().substring(0, 16)}',
      );
      
      _showSnackBar('Calibration saved!');
      
      // Return to previous screen
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Error saving calibration: $e');
    }
  }
  
  /// Show a snack bar with a message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Violin Posture Calibration'),
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (!_isCameraInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Column(
      children: [
        // Camera preview
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              ),
              
              // Overlay for instructions
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: _buildInstructionOverlay(),
              ),
            ],
          ),
        ),
        
        // Controls
        Expanded(
          flex: 1,
          child: _buildControls(),
        ),
      ],
    );
  }
  
  Widget _buildInstructionOverlay() {
    final currentStepData = _calibrationSteps[_currentStep];
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${_currentStep + 1}: ${currentStepData['title']}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentStepData['description'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentStepData['instruction'],
            style: const TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.grey[100],
      child: Column(
        children: [
          Text(
            'Step ${_currentStep + 1} of ${_calibrationSteps.length}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                onPressed: _currentStep > 0 ? _previousStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
              
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture'),
                onPressed: _isCapturing ? null : _capturePosition,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: Text(_currentStep < _calibrationSteps.length - 1 ? 'Next' : 'Finish'),
                onPressed: _calibrationData.containsKey('step_$_currentStep') ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Import Math from dart:math as Math to avoid clashing with our methods
class Math {
  static double sqrt(double value) => math.sqrt(value);
  static double acos(double value) => math.acos(value);
  static const double pi = math.pi;
}