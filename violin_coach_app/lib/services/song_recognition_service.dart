import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';

/// A service for recognizing songs using the ACRCloud API (Shazam-like functionality).
class SongRecognitionService {
  // Singleton pattern
  static final SongRecognitionService _instance = SongRecognitionService._internal();
  factory SongRecognitionService() => _instance;
  SongRecognitionService._internal();
  
  // ACRCloud API credentials - Replace with your own from https://www.acrcloud.com/
  static const String _host = 'identify-eu-west-1.acrcloud.com';
  static const String _accessKey = 'YOUR_ACCESS_KEY'; // Replace with your ACRCloud access key
  static const String _accessSecret = 'YOUR_ACCESS_SECRET'; // Replace with your ACRCloud access secret
  static const String _endpoint = '/v1/identify';
  
  // Recording properties
  final _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  String? _recordingPath;
  
  /// Initialize the song recognition service
  Future<void> initialize() async {
    if (_isRecorderInitialized) return;
    
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission is required for song recognition');
    }
    
    await _recorder.openRecorder();
    _isRecorderInitialized = true;
  }
  
  /// Start recording audio for recognition
  Future<void> startRecording() async {
    if (!_isRecorderInitialized) {
      await initialize();
    }
    
    if (_isRecording) return;
    
    // Create a temporary file for the recording
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/song_recognition_${DateTime.now().millisecondsSinceEpoch}.aac';
    
    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
      bitRate: 128000, // 128 kbps
      sampleRate: 44100, // 44.1 kHz
    );
    
    _isRecording = true;
    _recordingPath = path;
  }
  
  /// Stop recording and recognize the song
  Future<Map<String, dynamic>> stopRecordingAndRecognize() async {
    if (!_isRecording || _recordingPath == null) {
      throw Exception('Not recording');
    }
    
    // Stop recording
    await _recorder.stopRecorder();
    _isRecording = false;
    
    // Recognize the song
    final result = await _recognizeSong(_recordingPath!);
    
    // Save to history if successful
    if (result['status'] == 'success' && result['metadata'] != null) {
      await _saveToHistory(result);
    }
    
    return result;
  }
  
  /// Recognize a song from a file
  Future<Map<String, dynamic>> _recognizeSong(String filePath) async {
    try {
      // Read the file as bytes
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      // Prepare the request
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final stringToSign = 'POST\n$_endpoint\n$_accessKey\naudio\n1\n$timestamp';
      final hmac = Hmac(sha1, utf8.encode(_accessSecret));
      final signature = base64.encode(hmac.convert(utf8.encode(stringToSign)).bytes);
      
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.https(_host, _endpoint));
      
      // Add form fields
      request.fields.addAll({
        'access_key': _accessKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
        'data_type': 'audio',
        'sample_bytes': bytes.length.toString(),
      });
      
      // Add audio file
      request.files.add(http.MultipartFile.fromBytes(
        'sample',
        bytes,
        filename: 'sample.aac',
      ));
      
      // Send the request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      // Parse the response
      final jsonResponse = json.decode(responseBody);
      
      if (response.statusCode == 200) {
        if (jsonResponse['status']['code'] == 0) {
          // Successful recognition
          final metadata = jsonResponse['metadata'];
          if (metadata['music'] != null && metadata['music'].isNotEmpty) {
            final music = metadata['music'][0];
            
            return {
              'status': 'success',
              'metadata': {
                'title': music['title'],
                'artist': music['artists'] != null && music['artists'].isNotEmpty
                    ? music['artists'][0]['name']
                    : 'Unknown Artist',
                'album': music['album'] != null ? music['album']['name'] : null,
                'release_date': music['release_date'],
                'genres': music['genres'] != null
                    ? List<String>.from(music['genres'].map((g) => g['name']))
                    : [],
                'confidence': music['score'],
                'external_ids': music['external_ids'],
              },
            };
          }
        }
        
        // No match found
        return {
          'status': 'no_match',
          'message': 'No matching songs found',
        };
      } else {
        // Error
        return {
          'status': 'error',
          'message': 'API error: ${jsonResponse['status']['msg']}',
          'code': jsonResponse['status']['code'],
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Recognition failed: $e',
      };
    }
  }
  
  /// Save a recognized song to the history
  Future<void> _saveToHistory(Map<String, dynamic> result) async {
    try {
      final metadata = result['metadata'];
      final db = DatabaseHelper();
      
      await db.insert('song_recognition_history', {
        'id': const Uuid().v4(),
        'user_id': 'current_user_id', // Replace with actual user ID
        'song_title': metadata['title'],
        'artist': metadata['artist'],
        'recognition_timestamp': DateTime.now().toIso8601String(),
        'confidence_score': metadata['confidence'],
      });
    } catch (e) {
      print('Failed to save to history: $e');
    }
  }
  
  /// Get song recognition history
  Future<List<Map<String, dynamic>>> getHistory(String userId) async {
    try {
      final db = DatabaseHelper();
      
      final results = await db.query(
        'song_recognition_history',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'recognition_timestamp DESC',
        limit: 50,
      );
      
      return results;
    } catch (e) {
      print('Failed to get history: $e');
      return [];
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _recorder.closeRecorder();
    _isRecorderInitialized = false;
    _isRecording = false;
    _recordingPath = null;
  }
}