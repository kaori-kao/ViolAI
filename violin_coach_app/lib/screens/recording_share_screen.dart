import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/classroom_service.dart';

class RecordingShareScreen extends StatefulWidget {
  const RecordingShareScreen({Key? key}) : super(key: key);

  @override
  State<RecordingShareScreen> createState() => _RecordingShareScreenState();
}

class _RecordingShareScreenState extends State<RecordingShareScreen> {
  final _recorder = FlutterSoundRecorder();
  final _player = FlutterSoundPlayer();
  final _authService = AuthService();
  final _classroomService = ClassroomService();
  
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordingPath;
  String _recordingTitle = '';
  String? _selectedClassroomId;
  String? _selectedTeacherId;
  List<dynamic> _classrooms = [];
  List<User> _teachers = [];
  bool _isUploading = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _initializePlayer();
    _loadClassrooms();
  }
  
  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }
  
  Future<void> _initializeRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() {
        _errorMessage = 'Microphone permission is required';
      });
      return;
    }
    
    await _recorder.openRecorder();
    setState(() {
      _isRecorderInitialized = true;
    });
  }
  
  Future<void> _initializePlayer() async {
    await _player.openPlayer();
    setState(() {
      _isPlayerInitialized = true;
    });
  }
  
  Future<void> _loadClassrooms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final classrooms = await _classroomService.getStudentClassrooms();
      
      // For demo purposes, we'll use the demo teachers
      // In a real app, this would come from the API
      final teachers = [
        User(
          id: '9f8e3e1d-4c9e-4f5a-8a7b-9d1a7c5e4f3d',
          username: 'teacher',
          email: 'teacher@example.com',
          name: 'John Smith',
          role: UserRole.teacher,
          createdAt: DateTime.now().subtract(const Duration(days: 120)),
        ),
      ];
      
      setState(() {
        _classrooms = classrooms;
        _teachers = teachers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load classrooms: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _toggleRecording() async {
    if (!_isRecorderInitialized) {
      setState(() {
        _errorMessage = 'Recorder not initialized';
      });
      return;
    }
    
    if (_isRecording) {
      // Stop recording
      _recordingPath = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });
    } else {
      // Start recording
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';
      
      await _recorder.startRecorder(toFile: path);
      setState(() {
        _isRecording = true;
        _recordingPath = null;
      });
    }
  }
  
  Future<void> _togglePlayback() async {
    if (!_isPlayerInitialized || _recordingPath == null) {
      return;
    }
    
    if (_isPlaying) {
      await _player.stopPlayer();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _player.startPlayer(
        fromURI: _recordingPath,
        whenFinished: () {
          setState(() {
            _isPlaying = false;
          });
        },
      );
      setState(() {
        _isPlaying = true;
      });
    }
  }
  
  Future<void> _shareRecording() async {
    if (_recordingPath == null) {
      setState(() {
        _errorMessage = 'No recording to share';
      });
      return;
    }
    
    if (_recordingTitle.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a title for your recording';
      });
      return;
    }
    
    if (_selectedClassroomId == null && _selectedTeacherId == null) {
      setState(() {
        _errorMessage = 'Please select a classroom or teacher to share with';
      });
      return;
    }
    
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });
    
    try {
      // In a real app, this would upload the file to a server
      // and create a database record
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _isUploading = false;
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording shared successfully')),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to share recording: $e';
        _isUploading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record & Share'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Recording controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Record Your Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording
                          ? 'Recording in progress...'
                          : _recordingPath != null
                              ? 'Recording complete'
                              : 'Tap the button to start recording',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Record button
                        ElevatedButton.icon(
                          onPressed:
                              _isRecorderInitialized && !_isPlaying ? _toggleRecording : null,
                          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                          label: Text(_isRecording ? 'Stop' : 'Record'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isRecording ? Colors.red : Theme.of(context).primaryColor,
                            minimumSize: const Size(120, 48),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Play button
                        ElevatedButton.icon(
                          onPressed: _recordingPath != null && !_isRecording
                              ? _togglePlayback
                              : null,
                          icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                          label: Text(_isPlaying ? 'Stop' : 'Play'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(120, 48),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Only show the rest if we have a recording
            if (_recordingPath != null) ...[
              const Text(
                'Share Your Recording',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Recording title
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Recording Title',
                  hintText: 'e.g., Twinkle Twinkle Little Star',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _recordingTitle = value;
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Choose classroom or teacher
              const Text(
                'Share with:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Classroom selection
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _classrooms.isEmpty
                      ? const Text(
                          'You are not in any classrooms yet',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Column(
                          children: [
                            const Text('Select a Classroom:'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              hint: const Text('Select a classroom'),
                              value: _selectedClassroomId,
                              onChanged: (value) {
                                setState(() {
                                  _selectedClassroomId = value;
                                  _selectedTeacherId = null;
                                });
                              },
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('None'),
                                ),
                                ..._classrooms.map((classroom) {
                                  return DropdownMenuItem<String>(
                                    value: classroom.id,
                                    child: Text(classroom.name),
                                  );
                                }).toList(),
                              ],
                            ),
                          ],
                        ),
              
              const SizedBox(height: 16),
              
              // Teacher selection
              _teachers.isEmpty
                  ? Container()
                  : Column(
                      children: [
                        const Text('Or Select a Teacher:'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          hint: const Text('Select a teacher'),
                          value: _selectedTeacherId,
                          onChanged: (value) {
                            setState(() {
                              _selectedTeacherId = value;
                              _selectedClassroomId = null;
                            });
                          },
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('None'),
                            ),
                            ..._teachers.map((teacher) {
                              return DropdownMenuItem<String>(
                                value: teacher.id,
                                child: Text(teacher.name),
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    ),
              
              const SizedBox(height: 24),
              
              // Share button
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _shareRecording,
                icon: _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.share),
                label: Text(_isUploading ? 'Sharing...' : 'Share Recording'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}