import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/pose_detector_service.dart';
import '../services/audio_analyzer_service.dart';

class BowNoteSyncScreen extends StatefulWidget {
  final String? pieceName;
  
  const BowNoteSyncScreen({
    Key? key,
    this.pieceName = 'Twinkle Twinkle Little Star',
  }) : super(key: key);

  @override
  State<BowNoteSyncScreen> createState() => _BowNoteSyncScreenState();
}

class _BowNoteSyncScreenState extends State<BowNoteSyncScreen>
    with WidgetsBindingObserver {
  // Services
  final _authService = AuthService();
  final _poseDetector = PoseDetectorService();
  final _audioAnalyzer = AudioAnalyzerService();
  
  // Camera
  List<CameraDescription>? _cameras;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  
  // Pose and Audio Analysis
  bool _isPoseDetectorInitialized = false;
  bool _isAudioAnalyzerInitialized = false;
  bool _isAnalysisActive = false;
  String? _sessionId;
  
  // Feedback states
  String _bowDirection = 'none';
  String _detectedNote = '';
  double _bowNoteAccuracy = 0.0;
  double _postureScore = 0.0;
  int _noteCount = 0;
  
  // Timer for regular updates
  Timer? _analysisTimer;
  
  // UI States
  bool _isLoading = true;
  String? _errorMessage;
  bool _showResults = false;
  Map<String, dynamic> _sessionResults = {};
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAnalysis();
    _cameraController?.dispose();
    _analysisTimer?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopAnalysis();
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }
  
  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Check permissions
      final cameraStatus = await Permission.camera.request();
      final microphoneStatus = await Permission.microphone.request();
      
      if (cameraStatus != PermissionStatus.granted ||
          microphoneStatus != PermissionStatus.granted) {
        setState(() {
          _errorMessage = 'Camera and microphone permissions are required';
          _isLoading = false;
        });
        return;
      }
      
      // Initialize pose detector
      await _poseDetector.initialize();
      _isPoseDetectorInitialized = true;
      
      // Initialize audio analyzer
      await _audioAnalyzer.initialize();
      _isAudioAnalyzerInitialized = true;
      
      // Initialize camera
      await _initializeCamera();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize services: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras available';
          _isLoading = false;
        });
        return;
      }
      
      // Use the front camera
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      
      // Create controller
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      
      // Initialize controller
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _startAnalysis() async {
    if (!_isCameraInitialized || !_isPoseDetectorInitialized || !_isAudioAnalyzerInitialized) {
      setState(() {
        _errorMessage = 'Services not fully initialized';
      });
      return;
    }
    
    try {
      // Get current user
      final user = _authService.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'You must be logged in';
        });
        return;
      }
      
      // Start camera stream
      await _cameraController!.startImageStream(_processCameraImage);
      
      // Start audio analysis
      _sessionId = await _audioAnalyzer.startSession(
        user.id,
        widget.pieceName ?? 'Practice Session',
      );
      
      // Start timer for regular updates
      _analysisTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _updateAnalysis(),
      );
      
      setState(() {
        _isAnalysisActive = true;
        _noteCount = 0;
        _bowDirection = 'none';
        _detectedNote = '';
        _bowNoteAccuracy = 0.0;
        _postureScore = 80.0 + (20.0 * (math.Random().nextDouble())); // Mock value
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start analysis: $e';
      });
    }
  }
  
  Future<void> _stopAnalysis() async {
    if (!_isAnalysisActive) return;
    
    try {
      // Stop camera stream
      await _cameraController?.stopImageStream();
      
      // Stop timer
      _analysisTimer?.cancel();
      
      // Stop audio analysis and get results
      if (_sessionId != null) {
        final results = await _audioAnalyzer.stopSession(
          postureScore: _postureScore,
          bowDirectionAccuracy: _bowNoteAccuracy,
          rhythmScore: 85.0 + (15.0 * (math.Random().nextDouble())), // Mock value
        );
        
        setState(() {
          _sessionResults = results;
          _showResults = true;
        });
      }
      
      setState(() {
        _isAnalysisActive = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to stop analysis: $e';
      });
    }
  }
  
  void _processCameraImage(CameraImage image) async {
    if (!_isAnalysisActive) return;
    
    try {
      // Process image for pose detection
      final poseData = await _poseDetector.processImage(image);
      
      // Extract bow direction from pose data
      final keypoints = poseData['keypoints'] as Map<String, List<double>>;
      
      if (keypoints.containsKey('right_shoulder') &&
          keypoints.containsKey('right_elbow') &&
          keypoints.containsKey('right_wrist')) {
        
        // Calculate the angle of the right arm
        final angle = _poseDetector.calculateAngle(
          keypoints['right_shoulder']!,
          keypoints['right_elbow']!,
          keypoints['right_wrist']!,
        );
        
        // Determine bow direction based on angle change
        // This is a simplified model that would be more sophisticated in a real app
        String newDirection;
        if (angle > 130) {
          newDirection = 'down';
        } else if (angle < 90) {
          newDirection = 'up';
        } else {
          newDirection = _bowDirection;
        }
        
        if (newDirection != _bowDirection) {
          // Update bow direction in the audio analyzer
          _audioAnalyzer.updateBowDirection(newDirection);
          
          setState(() {
            _bowDirection = newDirection;
          });
        }
      }
    } catch (e) {
      print('Error processing image: $e');
    }
  }
  
  void _updateAnalysis() {
    if (!_isAnalysisActive) return;
    
    try {
      // Get current note events
      final noteEvents = _audioAnalyzer.getNoteEvents();
      
      if (noteEvents.isNotEmpty) {
        final latestNote = noteEvents.last;
        
        setState(() {
          _detectedNote = latestNote['note'] as String;
          _noteCount = noteEvents.length;
          
          // Update bow-note accuracy (mock calculation)
          if (_noteCount > 5) {
            _bowNoteAccuracy = 70.0 + (30.0 * (math.Random().nextDouble()));
          }
        });
      }
    } catch (e) {
      print('Error updating analysis: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pieceName ?? 'Bow-Note Sync'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _showResults
                  ? _buildResultsView()
                  : _buildMainView(),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeServices,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMainView() {
    return Column(
      children: [
        // Camera preview
        Expanded(
          flex: 3,
          child: _isCameraInitialized
              ? Stack(
                  children: [
                    // Camera preview
                    Center(
                      child: CameraPreview(_cameraController!),
                    ),
                    
                    // Overlay with bow direction indicator
                    Positioned(
                      top: 16,
                      left: 16,
                      child: _buildBowDirectionIndicator(),
                    ),
                    
                    // Detected note
                    if (_isAnalysisActive && _detectedNote.isNotEmpty)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Note: $_detectedNote',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : const Center(
                  child: Text('Camera not initialized'),
                ),
        ),
        
        // Feedback panel
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.grey[100],
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: _isAnalysisActive
                ? _buildActiveFeedbackPanel()
                : _buildStartSessionPanel(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildBowDirectionIndicator() {
    Color backgroundColor;
    IconData iconData;
    String label;
    
    switch (_bowDirection) {
      case 'up':
        backgroundColor = Colors.green;
        iconData = Icons.arrow_upward;
        label = 'Up Bow';
        break;
      case 'down':
        backgroundColor = Colors.blue;
        iconData = Icons.arrow_downward;
        label = 'Down Bow';
        break;
      default:
        backgroundColor = Colors.grey;
        iconData = Icons.remove;
        label = 'No Bow';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            iconData,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            label,
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
  
  Widget _buildStartSessionPanel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Ready to practice?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This session will analyze your bow direction and notes to help improve your playing.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _startAnalysis,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Practice Session'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActiveFeedbackPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Session details
        Text(
          'Practicing: ${widget.pieceName ?? 'Violin Piece'}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Stats
        Row(
          children: [
            _buildStatCard(
              'Notes Played',
              _noteCount.toString(),
              Icons.music_note,
              Colors.purple,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              'Bow-Note Sync',
              '${_bowNoteAccuracy.toStringAsFixed(1)}%',
              Icons.sync,
              _bowNoteAccuracy >= 80 ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              'Posture',
              '${_postureScore.toStringAsFixed(1)}%',
              Icons.accessibility_new,
              _postureScore >= 80 ? Colors.green : Colors.orange,
            ),
          ],
        ),
        
        const Spacer(),
        
        // Stop button
        ElevatedButton.icon(
          onPressed: _stopAnalysis,
          icon: const Icon(Icons.stop),
          label: const Text('End Session'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultsView() {
    final overallScore = _sessionResults['overall_score'] as double?;
    final duration = _sessionResults['duration_seconds'] as int?;
    final noteCount = _sessionResults['note_count'] as int?;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Session Complete!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildResultRow(
                    'Piece',
                    widget.pieceName ?? 'Practice Session',
                    Icons.music_note,
                  ),
                  const Divider(),
                  _buildResultRow(
                    'Duration',
                    duration != null
                        ? '${(duration / 60).floor()}:${(duration % 60).toString().padLeft(2, '0')}'
                        : '0:00',
                    Icons.timer,
                  ),
                  const Divider(),
                  _buildResultRow(
                    'Notes Played',
                    noteCount?.toString() ?? '0',
                    Icons.piano,
                  ),
                  const Divider(),
                  _buildResultRow(
                    'Posture Score',
                    '${_postureScore.toStringAsFixed(1)}%',
                    Icons.accessibility_new,
                    valueColor: _getScoreColor(_postureScore),
                  ),
                  const Divider(),
                  _buildResultRow(
                    'Bow-Note Accuracy',
                    '${_bowNoteAccuracy.toStringAsFixed(1)}%',
                    Icons.sync,
                    valueColor: _getScoreColor(_bowNoteAccuracy),
                  ),
                  if (overallScore != null) ...[
                    const Divider(),
                    _buildResultRow(
                      'Overall Performance',
                      '${overallScore.toStringAsFixed(1)}%',
                      Icons.stars,
                      valueColor: _getScoreColor(overallScore),
                      isHighlighted: true,
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showResults = false;
                        _isAnalysisActive = false;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Practice Again'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlighted ? 18 : 16,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }
}

// For mock data in demo version
class math {
  static Random random = Random();
}

class Random {
  double nextDouble() {
    return DateTime.now().millisecondsSinceEpoch % 100 / 100;
  }
}