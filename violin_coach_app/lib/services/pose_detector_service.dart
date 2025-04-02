import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

/// A service for performing 3D pose detection using TCPformer model.
class PoseDetectorService {
  // Singleton pattern
  static final PoseDetectorService _instance = PoseDetectorService._internal();
  factory PoseDetectorService() => _instance;
  PoseDetectorService._internal();
  
  // Properties
  Interpreter? _interpreter;
  bool _isInitialized = false;
  
  // Model parameters
  static const int _inputSize = 256;
  static const int _jointCount = 17; // Number of keypoints in the COCO format
  static const int _dimensionCount = 3; // 3D pose estimation (x, y, z)
  
  // The order of keypoints in the COCO format
  static const List<String> _jointNames = [
    'nose',
    'left_eye',
    'right_eye',
    'left_ear',
    'right_ear',
    'left_shoulder',
    'right_shoulder',
    'left_elbow',
    'right_elbow',
    'left_wrist',
    'right_wrist',
    'left_hip',
    'right_hip',
    'left_knee',
    'right_knee',
    'left_ankle',
    'right_ankle',
  ];
  
  // Connection pairs for drawing skeleton
  static const List<List<int>> _skeletonConnections = [
    [0, 1], [0, 2], [1, 3], [2, 4], // Face
    [5, 7], [7, 9], [6, 8], [8, 10], // Arms
    [5, 6], [5, 11], [6, 12], [11, 12], // Torso
    [11, 13], [13, 15], [12, 14], [14, 16], // Legs
  ];
  
  /// Initialize the pose detector service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load the model files from assets
      final modelFile = await _loadModelFile('assets/models/tcpformer_pose.tflite');
      
      // Create interpreter options
      final options = InterpreterOptions();
      options.threads = 4; // Use 4 threads for inference
      
      // Create the interpreter
      _interpreter = InterpreterOptions().addDelegate(GpuDelegateV2());
      _interpreter = await Interpreter.fromFile(modelFile, options: options);
      
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize pose detector: $e');
      _isInitialized = false;
    }
  }
  
  /// Load the model file from assets and save it to the device
  Future<File> _loadModelFile(String assetPath) async {
    // Get temporary directory
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/tcpformer_model.tflite';
    final tempFile = File(tempPath);
    
    // Check if the file already exists
    if (await tempFile.exists()) {
      return tempFile;
    }
    
    // Load the model file from assets and save it to the device
    final modelData = await rootBundle.load(assetPath);
    await tempFile.writeAsBytes(modelData.buffer.asUint8List());
    
    return tempFile;
  }
  
  /// Process a camera image and detect poses
  Future<Map<String, dynamic>> processImage(CameraImage cameraImage) async {
    if (!_isInitialized || _interpreter == null) {
      throw Exception('Pose detector not initialized');
    }
    
    // Convert CameraImage to a format suitable for inference
    final inputImage = await _convertCameraImageToInputImage(cameraImage);
    
    // Define input and output tensors
    final inputTensor = [inputImage];
    final outputTensor = List.filled(
      1 * _jointCount * _dimensionCount,
      0.0,
    ).reshape([1, _jointCount, _dimensionCount]);
    
    // Run inference
    _interpreter!.run(inputTensor, outputTensor);
    
    // Process the results
    final keypoints3D = outputTensor[0] as List<List<double>>;
    
    // Create a map of joint names to their 3D coordinates
    final jointMap = <String, List<double>>{};
    for (int i = 0; i < _jointNames.length; i++) {
      jointMap[_jointNames[i]] = keypoints3D[i];
    }
    
    return {
      'keypoints': jointMap,
      'connections': _skeletonConnections,
    };
  }
  
  /// Convert a camera image to the input format required by the model
  Future<List<List<List<double>>>> _convertCameraImageToInputImage(
    CameraImage cameraImage,
  ) async {
    // Convert CameraImage to img.Image
    final width = cameraImage.width;
    final height = cameraImage.height;
    
    img.Image? image;
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      image = _convertYUV420ToImage(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: cameraImage.planes[0].bytes.buffer,
        order: img.ChannelOrder.bgra,
      );
    } else {
      throw Exception('Unsupported image format: ${cameraImage.format.group}');
    }
    
    // Resize the image to the input size
    final resizedImage = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.average,
    );
    
    // Convert the image to a 3D tensor of shape [height, width, channels]
    final inputImage = List.generate(
      _inputSize,
      (y) => List.generate(
        _inputSize,
        (x) => [
          resizedImage.getPixel(x, y).r / 255.0,
          resizedImage.getPixel(x, y).g / 255.0,
          resizedImage.getPixel(x, y).b / 255.0,
        ],
      ),
    );
    
    return inputImage;
  }
  
  /// Convert a YUV420 image to RGB format
  img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    
    final yBuffer = cameraImage.planes[0].bytes;
    final uBuffer = cameraImage.planes[1].bytes;
    final vBuffer = cameraImage.planes[2].bytes;
    
    final yStride = cameraImage.planes[0].bytesPerRow;
    final uStride = cameraImage.planes[1].bytesPerRow;
    final vStride = cameraImage.planes[2].bytesPerRow;
    
    final yPixelStride = cameraImage.planes[0].bytesPerPixel!;
    final uPixelStride = cameraImage.planes[1].bytesPerPixel!;
    final vPixelStride = cameraImage.planes[2].bytesPerPixel!;
    
    final image = img.Image(width: width, height: height);
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yStride + x * yPixelStride;
        final uIndex = (y ~/ 2) * uStride + (x ~/ 2) * uPixelStride;
        final vIndex = (y ~/ 2) * vStride + (x ~/ 2) * vPixelStride;
        
        final yValue = yBuffer[yIndex];
        final uValue = uBuffer[uIndex];
        final vValue = vBuffer[vIndex];
        
        // YUV to RGB conversion
        final r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
            .round()
            .clamp(0, 255);
        final b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);
        
        image.setPixelRgb(x, y, r, g, b);
      }
    }
    
    return image;
  }
  
  /// Draw pose skeleton on a canvas
  void drawPose({
    required Canvas canvas,
    required Size size,
    required Map<String, dynamic> poseData,
    Color jointColor = Colors.red,
    Color connectionColor = Colors.green,
    double jointRadius = 6.0,
    double connectionWidth = 2.0,
  }) {
    final keypoints = poseData['keypoints'] as Map<String, List<double>>;
    final connections = poseData['connections'] as List<List<int>>;
    
    final jointPaint = Paint()
      ..color = jointColor
      ..style = PaintingStyle.fill;
    
    final connectionPaint = Paint()
      ..color = connectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = connectionWidth;
    
    // Draw connections (skeleton)
    for (final connection in connections) {
      final startJoint = _jointNames[connection[0]];
      final endJoint = _jointNames[connection[1]];
      
      if (!keypoints.containsKey(startJoint) || !keypoints.containsKey(endJoint)) {
        continue;
      }
      
      final startPoint = Offset(
        keypoints[startJoint]![0] * size.width,
        keypoints[startJoint]![1] * size.height,
      );
      
      final endPoint = Offset(
        keypoints[endJoint]![0] * size.width,
        keypoints[endJoint]![1] * size.height,
      );
      
      canvas.drawLine(startPoint, endPoint, connectionPaint);
    }
    
    // Draw joints (keypoints)
    for (final jointName in keypoints.keys) {
      final joint = keypoints[jointName]!;
      
      final jointCenter = Offset(
        joint[0] * size.width,
        joint[1] * size.height,
      );
      
      canvas.drawCircle(jointCenter, jointRadius, jointPaint);
    }
  }
  
  /// Calculate the angle between three joints
  double calculateAngle(
    List<double> joint1,
    List<double> joint2,
    List<double> joint3,
  ) {
    // Calculate vectors
    final vector1 = [
      joint1[0] - joint2[0],
      joint1[1] - joint2[1],
      joint1[2] - joint2[2],
    ];
    
    final vector2 = [
      joint3[0] - joint2[0],
      joint3[1] - joint2[1],
      joint3[2] - joint2[2],
    ];
    
    // Calculate dot product
    final dotProduct = vector1[0] * vector2[0] +
        vector1[1] * vector2[1] +
        vector1[2] * vector2[2];
    
    // Calculate magnitudes
    final magnitude1 = _calculateMagnitude(vector1);
    final magnitude2 = _calculateMagnitude(vector2);
    
    // Calculate angle in radians and convert to degrees
    final angleRadians = Math.acos(dotProduct / (magnitude1 * magnitude2));
    final angleDegrees = angleRadians * 180 / Math.pi;
    
    return angleDegrees;
  }
  
  /// Calculate the magnitude of a 3D vector
  double _calculateMagnitude(List<double> vector) {
    return Math.sqrt(
      vector[0] * vector[0] + vector[1] * vector[1] + vector[2] * vector[2],
    );
  }
  
  /// Dispose of resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

/// Math utility class
class Math {
  static double acos(double x) {
    return Math.atan2(Math.sqrt(1 - x * x), x);
  }
  
  static double atan2(double y, double x) {
    return Math.atan(y / x);
  }
  
  static double atan(double x) {
    return Math.asin(x / Math.sqrt(1 + x * x));
  }
  
  static double asin(double x) {
    return Math.atan(x / Math.sqrt(1 - x * x));
  }
  
  static double sqrt(double x) {
    return math.sqrt(x);
  }
  
  static double pi = 3.1415926535897932;
}