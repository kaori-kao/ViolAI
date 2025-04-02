import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';
import '../models/practice_session.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<PracticeSession> _sessions = [];
  bool _isLoading = true;
  int? _currentUserId;
  
  @override
  void initState() {
    super.initState();
    _initializeUser();
  }
  
  /// Initialize user and load practice history
  Future<void> _initializeUser() async {
    try {
      // Get default user
      final user = await _dbHelper.getUserByUsername('default_user');
      if (user != null) {
        _currentUserId = user['id'] as int;
        await _loadPracticeHistory();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Load practice history from database
  Future<void> _loadPracticeHistory() async {
    if (_currentUserId == null) return;
    
    try {
      final sessions = await _dbHelper.getPracticeHistory(_currentUserId!, limit: 50);
      
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Error loading practice history: $e');
      setState(() {
        _isLoading = false;
      });
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
  
  /// View practice session details
  void _viewSessionDetails(PracticeSession session) async {
    // Load session events
    final events = await _dbHelper.getSessionEvents(session.id!);
    
    // Navigate to detail view or show modal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Practice Details',
                      style: Theme.of(context).textTheme.headline6,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                
                // Session info
                Text('Date: ${DateFormat('MMMM d, yyyy').format(session.startTime)}'),
                Text('Time: ${DateFormat('h:mm a').format(session.startTime)}'),
                Text('Duration: ${_formatDuration(session.durationSeconds ?? 0)}'),
                Text('Piece: ${session.pieceName}'),
                
                const SizedBox(height: 12),
                
                // Scores
                _buildScoreRow('Posture', session.postureScore),
                _buildScoreRow('Bow Direction', session.bowDirectionAccuracy),
                _buildScoreRow('Rhythm', session.rhythmScore),
                _buildScoreRow('Overall', session.overallScore, isOverall: true),
                
                const SizedBox(height: 16),
                
                // Events list
                Text(
                  'Practice Events',
                  style: Theme.of(context).textTheme.subtitle1?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return _buildEventCard(event);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  /// Build a score row with label and progress bar
  Widget _buildScoreRow(String label, double? score, {bool isOverall = false}) {
    final actualScore = score ?? 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: actualScore,
              backgroundColor: Colors.grey[300],
              color: isOverall
                  ? _getOverallScoreColor(actualScore)
                  : _getScoreColor(actualScore),
              minHeight: 10,
            ),
          ),
          const SizedBox(width: 8),
          Text('${(actualScore * 100).toInt()}%'),
        ],
      ),
    );
  }
  
  /// Build a card for practice event
  Widget _buildEventCard(dynamic event) {
    // Default icon and color
    IconData icon = Icons.event_note;
    Color color = Colors.grey;
    String title = 'Event';
    String subtitle = '';
    
    // Customize based on event type
    if (event.isPostureEvent) {
      icon = Icons.accessibility_new;
      color = Colors.purple;
      title = 'Posture';
      subtitle = event.parsedData['status'] ?? 'Posture correction';
    } else if (event.isBowDirectionEvent) {
      icon = Icons.swap_horiz;
      color = Colors.blue;
      title = 'Bow Direction';
      subtitle = event.parsedData['direction'] ?? 'Bow direction change';
    } else if (event.isRhythmEvent) {
      icon = Icons.music_note;
      color = Colors.orange;
      title = 'Rhythm';
      subtitle = event.parsedData['status'] ?? 'Rhythm progress';
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          DateFormat('h:mm:ss a').format(event.timestamp),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ),
    );
  }
  
  /// Format duration in seconds to readable string
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    
    return '$minutes min ${remainingSeconds.toString().padLeft(2, '0')} sec';
  }
  
  /// Get color for score based on value
  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.lime;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }
  
  /// Get color for overall score based on value
  Color _getOverallScoreColor(double score) {
    if (score >= 0.8) return Colors.blue;
    if (score >= 0.6) return Colors.lightBlue;
    if (score >= 0.4) return Colors.amber;
    return Colors.deepOrange;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildHistoryList(),
    );
  }
  
  Widget _buildHistoryList() {
    if (_sessions.isEmpty) {
      return const Center(
        child: Text(
          'No practice sessions yet.\nStart practicing to see your history!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _buildSessionCard(session);
      },
    );
  }
  
  Widget _buildSessionCard(PracticeSession session) {
    // Format date and time
    final date = DateFormat('MMM d, yyyy').format(session.startTime);
    final time = DateFormat('h:mm a').format(session.startTime);
    final duration = session.durationSeconds != null
        ? _formatDuration(session.durationSeconds!)
        : 'In progress';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () => _viewSessionDetails(session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session header
              Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.pieceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Session details
              Row(
                children: [
                  Icon(Icons.timer, color: Colors.grey[700], size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$time ($duration)',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Overall score
              if (session.overallScore != null)
                Row(
                  children: [
                    const Text(
                      'Overall Score: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: session.overallScore!,
                        backgroundColor: Colors.grey[300],
                        color: _getOverallScoreColor(session.overallScore!),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(session.overallScore! * 100).toInt()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}