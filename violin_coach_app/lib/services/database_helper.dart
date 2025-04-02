import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// A helper class for managing the SQLite database.
class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  
  static Database? _database;
  static const String dbName = 'violin_coach.db';
  
  // Database version - increment when schema changes
  static const int _dbVersion = 1;
  
  // Get database instance, creating it if needed
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  // Initialize the database
  Future<Database> _initDatabase() async {
    // Get path to the document directory on the device
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, dbName);
    
    // Open the database
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  // Create tables when the database is first created
  Future<void> _onCreate(Database db, int version) async {
    // User table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Practice sessions table
    await db.execute('''
      CREATE TABLE practice_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        duration_seconds INTEGER,
        piece_name TEXT,
        posture_score REAL,
        bow_direction_accuracy REAL,
        rhythm_score REAL,
        overall_score REAL,
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    
    // Practice events table
    await db.execute('''
      CREATE TABLE practice_events (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        event_type TEXT NOT NULL,
        event_data TEXT,
        FOREIGN KEY (session_id) REFERENCES practice_sessions (id) ON DELETE CASCADE
      )
    ''');
    
    // Calibration profiles table
    await db.execute('''
      CREATE TABLE calibration_profiles (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        calibration_data TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    
    // Classrooms table
    await db.execute('''
      CREATE TABLE classrooms (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        teacher_id TEXT NOT NULL,
        join_code TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        FOREIGN KEY (teacher_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    
    // Classroom students junction table
    await db.execute('''
      CREATE TABLE classroom_students (
        classroom_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        joined_at TEXT NOT NULL,
        PRIMARY KEY (classroom_id, user_id),
        FOREIGN KEY (classroom_id) REFERENCES classrooms (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    
    // Assignments table
    await db.execute('''
      CREATE TABLE assignments (
        id TEXT PRIMARY KEY,
        classroom_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        due_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (classroom_id) REFERENCES classrooms (id) ON DELETE CASCADE
      )
    ''');
    
    // Assignment submissions table
    await db.execute('''
      CREATE TABLE assignment_submissions (
        id TEXT PRIMARY KEY,
        assignment_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        recording_url TEXT NOT NULL,
        feedback TEXT,
        score REAL,
        submitted_at TEXT NOT NULL,
        FOREIGN KEY (assignment_id) REFERENCES assignments (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    
    // Recordings table
    await db.execute('''
      CREATE TABLE recordings (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        path TEXT NOT NULL,
        duration_seconds INTEGER,
        created_at TEXT NOT NULL,
        shared_with_user_id TEXT,
        shared_with_classroom_id TEXT,
        shared_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (shared_with_user_id) REFERENCES users (id) ON DELETE SET NULL,
        FOREIGN KEY (shared_with_classroom_id) REFERENCES classrooms (id) ON DELETE SET NULL
      )
    ''');
    
    // Song recognition history
    await db.execute('''
      CREATE TABLE song_recognition_history (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        song_title TEXT NOT NULL,
        artist TEXT,
        recognition_timestamp TEXT NOT NULL,
        confidence_score REAL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    
    // Note events table (for audio note detection)
    await db.execute('''
      CREATE TABLE note_events (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        note TEXT NOT NULL,
        frequency REAL NOT NULL,
        duration_ms INTEGER,
        bow_direction TEXT,
        FOREIGN KEY (session_id) REFERENCES practice_sessions (id) ON DELETE CASCADE
      )
    ''');
  }
  
  // Handle database version upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add migrations for version 2 here when needed
    }
    
    // Add more version upgrade blocks as needed
  }
  
  // Helper method for inserts
  Future<int> insert(String table, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert(table, row);
  }
  
  // Helper method for queries
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool distinct = false,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    Database db = await database;
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }
  
  // Helper method for updates
  Future<int> update(
    String table,
    Map<String, dynamic> row, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    Database db = await database;
    return await db.update(table, row, where: where, whereArgs: whereArgs);
  }
  
  // Helper method for deletes
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    Database db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }
  
  // Helper method for raw SQL queries
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    Database db = await database;
    return await db.rawQuery(sql, arguments);
  }
  
  // Helper method for raw SQL commands
  Future<int> rawExecute(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    Database db = await database;
    return await db.rawExecute(sql, arguments);
  }
  
  // Delete the database file
  Future<void> deleteDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, dbName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
  
  // Transaction helper
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    Database db = await database;
    return await db.transaction(action);
  }
}