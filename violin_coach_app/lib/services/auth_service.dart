import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';

/// A service that handles user authentication and session management.
class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  // Demo users for testing
  final Map<String, Map<String, dynamic>> _demoUsers = {
    'teacher': {
      'id': '9f8e3e1d-4c9e-4f5a-8a7b-9d1a7c5e4f3d',
      'username': 'teacher',
      'email': 'teacher@example.com',
      'password': 'password', // In a real app, this would be hashed
      'name': 'John Smith',
      'role': 'teacher',
      'created_at': DateTime.now().subtract(const Duration(days: 120)).toIso8601String(),
    },
    'student': {
      'id': '1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p',
      'username': 'student',
      'email': 'student@example.com',
      'password': 'password', // In a real app, this would be hashed
      'name': 'Jane Doe',
      'role': 'student',
      'created_at': DateTime.now().subtract(const Duration(days: 45)).toIso8601String(),
    },
  };
  
  // Stream controller for auth state changes
  final _authStateController = ValueNotifier<User?>(null);
  ValueListenable<User?> get authStateChanges => _authStateController;
  
  // Current user
  User? get currentUser => _authStateController.value;
  
  // Initialize the service
  Future<void> initialize() async {
    // Load from shared preferences if available
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    
    if (userData != null) {
      try {
        final jsonData = json.decode(userData);
        final user = User.fromJson(jsonData);
        _authStateController.value = user;
      } catch (e) {
        // Clear corrupted data
        await prefs.remove('user_data');
      }
    }
  }
  
  // Register a new user
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  }) async {
    try {
      // Check if username already exists
      if (_demoUsers.containsKey(username.toLowerCase())) {
        return {
          'success': false,
          'message': 'Username already taken',
        };
      }
      
      // Check if email already exists
      if (_demoUsers.values.any((u) => u['email'].toLowerCase() == email.toLowerCase())) {
        return {
          'success': false,
          'message': 'Email already registered',
        };
      }
      
      // Create new user
      final userId = const Uuid().v4();
      final newUser = {
        'id': userId,
        'username': username.toLowerCase(),
        'email': email.toLowerCase(),
        'password': password, // In a real app, this would be hashed
        'name': displayName ?? username,
        'role': role.toString().split('.').last,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Add to demo users
      _demoUsers[username.toLowerCase()] = newUser;
      
      return {
        'success': true,
        'message': 'Registration successful',
        'user': newUser,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration failed: $e',
      };
    }
  }
  
  // Login with username/email and password
  Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      // Try to find user by username
      Map<String, dynamic>? user = _demoUsers[usernameOrEmail.toLowerCase()];
      
      // If not found, try by email
      if (user == null) {
        user = _demoUsers.values.firstWhere(
          (u) => u['email'].toLowerCase() == usernameOrEmail.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
      }
      
      // Check if user exists
      if (user.isEmpty) {
        return {
          'success': false,
          'message': 'User not found',
        };
      }
      
      // Check password
      if (user['password'] != password) {
        return {
          'success': false,
          'message': 'Invalid password',
        };
      }
      
      // Login successful
      final loggedInUser = User.fromJson(user);
      
      // Update auth state
      _authStateController.value = loggedInUser;
      
      // Save to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', json.encode(user));
      
      return {
        'success': true,
        'message': 'Login successful',
        'user': loggedInUser,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Login failed: $e',
      };
    }
  }
  
  // Logout the current user
  Future<void> logout() async {
    // Clear auth state
    _authStateController.value = null;
    
    // Clear from shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }
  
  // Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      final user = _demoUsers.values.firstWhere(
        (u) => u['id'] == userId,
        orElse: () => <String, dynamic>{},
      );
      
      if (user.isEmpty) {
        return null;
      }
      
      return User.fromJson(user);
    } catch (e) {
      return null;
    }
  }
  
  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? name,
    String? email,
  }) async {
    try {
      // Find user
      final userEntry = _demoUsers.entries.firstWhere(
        (entry) => entry.value['id'] == userId,
        orElse: () => MapEntry('', {}),
      );
      
      if (userEntry.key.isEmpty) {
        return {
          'success': false,
          'message': 'User not found',
        };
      }
      
      // Update user data
      final user = userEntry.value;
      if (name != null) user['name'] = name;
      if (email != null) user['email'] = email.toLowerCase();
      
      // Update current user if it's the same
      if (currentUser?.id == userId) {
        _authStateController.value = User.fromJson(user);
        
        // Save to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', json.encode(user));
      }
      
      return {
        'success': true,
        'message': 'Profile updated successfully',
        'user': User.fromJson(user),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Profile update failed: $e',
      };
    }
  }
  
  // Change password
  Future<Map<String, dynamic>> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Find user
      final userEntry = _demoUsers.entries.firstWhere(
        (entry) => entry.value['id'] == userId,
        orElse: () => MapEntry('', {}),
      );
      
      if (userEntry.key.isEmpty) {
        return {
          'success': false,
          'message': 'User not found',
        };
      }
      
      // Check current password
      if (userEntry.value['password'] != currentPassword) {
        return {
          'success': false,
          'message': 'Current password is incorrect',
        };
      }
      
      // Update password
      userEntry.value['password'] = newPassword;
      
      return {
        'success': true,
        'message': 'Password changed successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Password change failed: $e',
      };
    }
  }
}