import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:convert';

import '../services/database_helper.dart';
import '../services/pose_detector_service.dart';
import '../utils/bow_direction_detector.dart';
import '../utils/posture_analyzer.dart';
import '../utils/rhythm_trainer.dart';
import '../models/practice_session.dart';
import 'bow_note_sync_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  bool _isPracticing = false;
  
  // Services
  final PoseDetectorService _poseDetector = PoseDetectorService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Utility classes
  final BowDirectionDetector _bowDetector = BowDirectionDetector();
  final PostureAnalyzer _postureAnalyzer = PostureAnalyzer();
  final RhythmTrainer _rhythmTrainer = RhythmTrainer();
  
  // Current session data
  int? _currentUserId;
  int? _currentSessionId;
  String _bowDirection = 'neutral';
  String _postureStatus = 'waiting';
  String _rhythmStatus = 'Ready to start';
  
  // Calibration data
  String? _calibrationData;
  bool _isCalibrated = false;
  
  // UI state
  bool _showControls = true;
  Timer? _controlsTimer;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _initializeUser();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _controlsTimer?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
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
  
  /// Initialize user and load calibration
  Future<void> _initializeUser() async {
    try {
      // Get or create default user
      final user = await _dbHelper.getUserByUsername('default_user');
      if (user != null) {
        _currentUserId = user['id'] as int;
        
        // Load calibration profile
        final calibration = await _dbHelper.getActiveCalibrationProfile(_currentUserId!);
        if (calibration != null) {
          setState(() {
            _calibrationData = calibration['calibration_data'] as String;
            _isCalibrated = true;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error loading user data: $e');
    }
  }
  
  /// Process camera image and detect pose
  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    
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
      
      // Process keypoints only if we're practicing
      if (_isPracticing) {
        _processKeypoints(keypoints3D);
      }
    } catch (e) {
      print('Error processing frame: $e');
    } finally {
      _isDetecting = false;
    }
  }
  
  /// Process keypoints for violin coaching
  void _processKeypoints(List<List<double>> keypoints) {
    // Get right elbow angle for bow direction
    final rightElbowAngle = _poseDetector.getRightElbowAngle();
    
    // Detect bow direction
    final bowResult = _bowDetector.detectBowDirection(rightElbowAngle);
    final newBowDirection = bowResult['direction'] as String;
    
    // Analyze posture if calibrated
    String newPostureStatus = 'waiting';
    if (_isCalibrated && _calibrationData != null) {
      final postureResult = _postureAnalyzer.analyzePosture(
        keypoints, 
        _calibrationData!,
      );
      
      newPostureStatus = postureResult['status'] as String;
      
      // Record posture event if changed significantly
      if (newPostureStatus != _postureStatus && _currentSessionId != null) {
        _dbHelper.recordPracticeEvent(
          _currentSessionId!,
          'posture_correction',
          json.encode({
            'status': newPostureStatus,
            'details': postureResult['feedback'],
          }),
        );
      }
    }
    
    // Update rhythm trainer if bow direction changed
    String newRhythmStatus = _rhythmStatus;
    if (newBowDirection != _bowDirection && newBowDirection != 'neutral' && _currentSessionId != null) {
      final rhythmResult = _rhythmTrainer.updateProgress(newBowDirection);
      newRhythmStatus = rhythmResult['status'] as String;
      
      // Record bow direction event
      _dbHelper.recordPracticeEvent(
        _currentSessionId!,
        'bow_direction_change',
        json.encode({
          'direction': newBowDirection,
          'angle': rightElbowAngle,
        }),
      );
      
      // Record rhythm progress event
      _dbHelper.recordPracticeEvent(
        _currentSessionId!,
        'rhythm_progress',
        json.encode(rhythmResult),
      );
    }
    
    // Update state with new values
    setState(() {
      _bowDirection = newBowDirection;
      _postureStatus = newPostureStatus;
      _rhythmStatus = newRhythmStatus;
    });
  }
  
  /// Start a new practice session
  void _startPracticeSession() async {
    if (_currentUserId == null) {
      _showSnackBar('User not initialized');
      return;
    }
    
    try {
      // Create new practice session
      final sessionId = await _dbHelper.createPracticeSession(_currentUserId!);
      
      setState(() {
        _currentSessionId = sessionId;
        _isPracticing = true;
        _rhythmTrainer.reset();
      });
      
      _showSnackBar('Practice session started');
      
      // Hide controls after 3 seconds
      _controlsTimer?.cancel();
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        setState(() {
          _showControls = false;
        });
      });
    } catch (e) {
      _showSnackBar('Error starting practice: $e');
    }
  }
  
  /// End the current practice session
  void _endPracticeSession() async {
    if (_currentSessionId == null) {
      _showSnackBar('No active practice session');
      return;
    }
    
    try {
      // Get progress stats
      final progressStats = _rhythmTrainer.getProgressStats();
      
      // End practice session with scores
      await _dbHelper.endPracticeSession(
        _currentSessionId!,
        postureScore: _postureStatus == 'excellent' ? 1.0 : 
                     _postureStatus == 'good' ? 0.8 : 
                     _postureStatus == 'fair' ? 0.6 : 0.4,
        bowScore: progressStats['accuracy'],
        rhythmScore: progressStats['progress_percent'],
        overallScore: (
          ((_postureStatus == 'excellent' ? 1.0 : 
            _postureStatus == 'good' ? 0.8 : 
            _postureStatus == 'fair' ? 0.6 : 0.4) + 
          progressStats['accuracy'] + 
          progressStats['progress_percent']) / 3
        ),
      );
      
      setState(() {
        _currentSessionId = null;
        _isPracticing = false;
        _showControls = true;
      });
      
      _showSnackBar('Practice session ended');
      
      // Store session ID before nullifying it
      final completedSessionId = _currentSessionId!;
      
      // Navigate to bow-note sync screen with the session ID
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BowNoteSyncScreen(sessionId: completedSessionId),
        ),
      );
    } catch (e) {
      _showSnackBar('Error ending practice: $e');
    }
  }
  
  /// Start calibration process
  void _startCalibration() {
    // TODO: Navigate to calibration screen
    _showSnackBar('Calibration coming soon');
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
  
  /// Toggle showing controls
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    
    if (_showControls && _isPracticing) {
      _controlsTimer?.cancel();
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        setState(() {
          _showControls = false;
        });
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Violin Coach'),
        actions: [
          IconButton(
            icon: const Icon(Icons.music_note),
            onPressed: () async {
              try {
                // Get the most recent session ID or create a new one
                int sessionId;
                if (_currentSessionId != null) {
                  sessionId = _currentSessionId!;
                } else {
                  // Get most recent session
                  final sessions = await _dbHelper.getPracticeHistory(_currentUserId ?? 1, limit: 1);
                  if (sessions.isNotEmpty) {
                    sessionId = sessions.first.id!;
                  } else {
                    // Create a new session if none exists
                    sessionId = await _dbHelper.createPracticeSession(_currentUserId ?? 1);
                  }
                }
                
                // Navigate to bow-note sync screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BowNoteSyncScreen(sessionId: sessionId),
                  ),
                );
              } catch (e) {
                _showSnackBar('Error loading note synchronization: $e');
              }
            },
            tooltip: 'Note Sync',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              // TODO: Navigate to analytics screen
            },
            tooltip: 'Analytics',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // TODO: Navigate to history screen
            },
            tooltip: 'History',
          ),
        ],
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
    
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          // Camera preview
          Center(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
          
          // Feedback overlay
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _buildFeedbackOverlay(),
          ),
          
          // Controls
          if (_showControls) _buildControls(),
        ],
      ),
    );
  }
  
  Widget _buildFeedbackOverlay() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bow: ${_bowDetector.getDirectionDescription()}',
            style: TextStyle(
              color: _bowDetector.getDirectionColor(),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Posture: ${_postureStatus.toUpperCase()}',
            style: TextStyle(
              color: _postureStatus == 'excellent' ? Colors.green :
                     _postureStatus == 'good' ? Colors.lightGreen :
                     _postureStatus == 'fair' ? Colors.yellow :
                     _postureStatus == 'poor' ? Colors.red : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rhythm: $_rhythmStatus',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControls() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (!_isCalibrated)
              ElevatedButton.icon(
                icon: const Icon(Icons.tune),
                label: const Text('Calibrate'),
                onPressed: _startCalibration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            
            if (!_isPracticing)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Practice'),
                onPressed: _isCalibrated ? _startPracticeSession : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text('End Practice'),
                onPressed: _endPracticeSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}