import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';
import '../models/practice_session.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<PracticeSession> _sessions = [];
  bool _isLoading = true;
  int? _currentUserId;
  
  // Metrics
  int _totalPracticeDuration = 0;
  int _totalSessions = 0;
  double _averagePostureScore = 0.0;
  double _averageBowScore = 0.0;
  double _averageRhythmScore = 0.0;
  double _averageOverallScore = 0.0;
  
  // For tab selection
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeUser();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  /// Initialize user and load practice history
  Future<void> _initializeUser() async {
    try {
      // Get default user
      final user = await _dbHelper.getUserByUsername('default_user');
      if (user != null) {
        _currentUserId = user['id'] as int;
        await _loadPracticeData();
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
  
  /// Load practice data from database
  Future<void> _loadPracticeData() async {
    if (_currentUserId == null) return;
    
    try {
      // Get all sessions
      final sessions = await _dbHelper.getPracticeHistory(_currentUserId!, limit: 100);
      
      // Calculate metrics
      _calculateMetrics(sessions);
      
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Error loading practice data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Calculate metrics from practice sessions
  void _calculateMetrics(List<PracticeSession> sessions) {
    if (sessions.isEmpty) return;
    
    _totalSessions = sessions.length;
    
    int totalDuration = 0;
    double totalPosture = 0.0;
    double totalBow = 0.0;
    double totalRhythm = 0.0;
    double totalOverall = 0.0;
    
    int postureCount = 0;
    int bowCount = 0;
    int rhythmCount = 0;
    int overallCount = 0;
    
    for (var session in sessions) {
      // Duration
      if (session.durationSeconds != null) {
        totalDuration += session.durationSeconds!;
      }
      
      // Posture score
      if (session.postureScore != null) {
        totalPosture += session.postureScore!;
        postureCount++;
      }
      
      // Bow direction score
      if (session.bowDirectionAccuracy != null) {
        totalBow += session.bowDirectionAccuracy!;
        bowCount++;
      }
      
      // Rhythm score
      if (session.rhythmScore != null) {
        totalRhythm += session.rhythmScore!;
        rhythmCount++;
      }
      
      // Overall score
      if (session.overallScore != null) {
        totalOverall += session.overallScore!;
        overallCount++;
      }
    }
    
    _totalPracticeDuration = totalDuration;
    _averagePostureScore = postureCount > 0 ? totalPosture / postureCount : 0.0;
    _averageBowScore = bowCount > 0 ? totalBow / bowCount : 0.0;
    _averageRhythmScore = rhythmCount > 0 ? totalRhythm / rhythmCount : 0.0;
    _averageOverallScore = overallCount > 0 ? totalOverall / overallCount : 0.0;
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
  
  /// Format duration in seconds to readable string
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '$hours h $minutes min';
    } else {
      return '$minutes min';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Progress'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildProgressTab(),
                _buildTrendsTab(),
              ],
            ),
    );
  }
  
  Widget _buildOverviewTab() {
    if (_sessions.isEmpty) {
      return const Center(
        child: Text(
          'No practice data available.\nStart practicing to see your analytics!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          _buildStatCards(),
          
          const SizedBox(height: 24),
          
          // Recent sessions
          Text(
            'Recent Sessions',
            style: Theme.of(context).textTheme.headline6,
          ),
          
          const SizedBox(height: 12),
          
          // Session timeline
          _buildSessionTimeline(),
        ],
      ),
    );
  }
  
  Widget _buildStatCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          title: 'Total Sessions',
          value: '$_totalSessions',
          icon: Icons.event_note,
          color: Colors.blue,
        ),
        _buildStatCard(
          title: 'Practice Time',
          value: _formatDuration(_totalPracticeDuration),
          icon: Icons.timer,
          color: Colors.green,
        ),
        _buildStatCard(
          title: 'Avg. Posture Score',
          value: '${(_averagePostureScore * 100).toInt()}%',
          icon: Icons.accessibility_new,
          color: Colors.purple,
        ),
        _buildStatCard(
          title: 'Avg. Rhythm Score',
          value: '${(_averageRhythmScore * 100).toInt()}%',
          icon: Icons.music_note,
          color: Colors.orange,
        ),
      ],
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSessionTimeline() {
    // Show only the last 5 sessions
    final recentSessions = _sessions.take(5).toList();
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentSessions.length,
      itemBuilder: (context, index) {
        final session = recentSessions[index];
        
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline indicator
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == 0 ? Colors.blue : Colors.grey[400],
                      ),
                    ),
                    if (index < recentSessions.length - 1)
                      Container(
                        width: 2,
                        height: 70,
                        color: Colors.grey[300],
                      ),
                  ],
                ),
                
                const SizedBox(width: 12),
                
                // Session card
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('MMM d, yyyy').format(session.startTime),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat('h:mm a').format(session.startTime),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${session.pieceName} (${_formatDuration(session.durationSeconds ?? 0)})',
                          ),
                          const SizedBox(height: 8),
                          if (session.overallScore != null)
                            LinearProgressIndicator(
                              value: session.overallScore!,
                              backgroundColor: Colors.grey[300],
                              color: _getScoreColor(session.overallScore!),
                              minHeight: 6,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildProgressTab() {
    if (_sessions.isEmpty) {
      return const Center(
        child: Text(
          'No practice data available.\nStart practicing to see your progress!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skill radar chart
          _buildSkillRadarChart(),
          
          const SizedBox(height: 24),
          
          // Overall progress
          Text(
            'Overall Progress',
            style: Theme.of(context).textTheme.headline6,
          ),
          
          const SizedBox(height: 12),
          
          // Progress chart
          _buildOverallProgressChart(),
        ],
      ),
    );
  }
  
  Widget _buildSkillRadarChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Skill Assessment',
              style: Theme.of(context).textTheme.subtitle1?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 20),
            
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  // This is a placeholder for a radar chart
                  // Libraries like fl_chart don't have a radar chart built in
                  // We would need to use a different chart library or build a custom widget
                  Container(
                    alignment: Alignment.center,
                    child: const Text(
                      'Radar Chart Visualization',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  
                  // Simple representation of skills with concentric circles
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: SkillsPainter(
                      postureScore: _averagePostureScore,
                      bowScore: _averageBowScore,
                      rhythmScore: _averageRhythmScore,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Posture', Colors.red),
                _buildLegendItem('Bow Technique', Colors.blue),
                _buildLegendItem('Rhythm', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
  
  Widget _buildOverallProgressChart() {
    // Filter out sessions with null overall scores
    final filteredSessions = _sessions
        .where((session) => session.overallScore != null)
        .toList();
    
    // Sort by date
    filteredSessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    if (filteredSessions.isEmpty) {
      return const Center(
        child: Text(
          'Not enough data to show progress chart.',
          style: TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text('${(value * 100).toInt()}%');
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < filteredSessions.length) {
                    final date = filteredSessions[value.toInt()].startTime;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('MM/dd').format(date),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade300),
          ),
          minX: 0,
          maxX: filteredSessions.length - 1.0,
          minY: 0,
          maxY: 1,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(filteredSessions.length, (index) {
                return FlSpot(
                  index.toDouble(),
                  filteredSessions[index].overallScore ?? 0,
                );
              }),
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrendsTab() {
    if (_sessions.isEmpty) {
      return const Center(
        child: Text(
          'No practice data available.\nStart practicing to see your trends!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Practice frequency
          Text(
            'Practice Frequency',
            style: Theme.of(context).textTheme.headline6,
          ),
          
          const SizedBox(height: 12),
          
          _buildPracticeFrequencyChart(),
          
          const SizedBox(height: 24),
          
          // Duration by week
          Text(
            'Practice Duration by Week',
            style: Theme.of(context).textTheme.headline6,
          ),
          
          const SizedBox(height: 12),
          
          _buildWeeklyDurationChart(),
        ],
      ),
    );
  }
  
  Widget _buildPracticeFrequencyChart() {
    // Group sessions by day of week
    final Map<int, int> sessionsByDayOfWeek = {
      1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0
    };
    
    for (var session in _sessions) {
      final dayOfWeek = session.startTime.weekday;
      sessionsByDayOfWeek[dayOfWeek] = (sessionsByDayOfWeek[dayOfWeek] ?? 0) + 1;
    }
    
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (sessionsByDayOfWeek.values.fold(0, (max, value) => value > max ? value : max) * 1.2).toDouble(),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('');
                  return Text(value.toInt().toString());
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  if (value >= 0 && value < days.length) {
                    return Text(days[value.toInt()]);
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (index) {
            final dayOfWeek = index + 1;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: sessionsByDayOfWeek[dayOfWeek]?.toDouble() ?? 0,
                  color: Colors.blue.shade300,
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
  
  Widget _buildWeeklyDurationChart() {
    // Group sessions by week
    final Map<int, int> durationByWeek = {};
    
    for (var session in _sessions) {
      if (session.durationSeconds == null) continue;
      
      // Calculate week number (simple approach)
      final weekNumber = session.startTime.difference(DateTime(2023, 1, 1)).inDays ~/ 7;
      
      durationByWeek[weekNumber] = (durationByWeek[weekNumber] ?? 0) + session.durationSeconds!;
    }
    
    // Sort weeks and take the last 8 (or less if we don't have 8 weeks of data)
    final sortedWeeks = durationByWeek.keys.toList()..sort();
    final recentWeeks = sortedWeeks.length <= 8 
        ? sortedWeeks 
        : sortedWeeks.sublist(sortedWeeks.length - 8);
    
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text('${(value / 60).toInt()}m');
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < recentWeeks.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'W${value.toInt() + 1}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade300),
          ),
          minX: 0,
          maxX: recentWeeks.length - 1.0,
          minY: 0,
          maxY: durationByWeek.values.isEmpty ? 3600 : 
                (durationByWeek.values.reduce((a, b) => a > b ? a : b) * 1.2).toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(recentWeeks.length, (index) {
                final week = recentWeeks[index];
                return FlSpot(
                  index.toDouble(),
                  durationByWeek[week]?.toDouble() ?? 0,
                );
              }),
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Get color for score based on value
  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.lime;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }
}

/// Custom painter for skills visualization
class SkillsPainter extends CustomPainter {
  final double postureScore;
  final double bowScore;
  final double rhythmScore;
  
  SkillsPainter({
    required this.postureScore,
    required this.bowScore,
    required this.rhythmScore,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = size.width / 2;
    
    // Draw concentric circles
    final circlePaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (int i = 1; i <= 4; i++) {
      final radius = maxRadius * i / 4;
      canvas.drawCircle(Offset(centerX, centerY), radius, circlePaint);
    }
    
    // Draw skill values
    final skillPaint = Paint()
      ..style = PaintingStyle.fill;
    
    // Posture (top)
    final posturePoint = Offset(
      centerX,
      centerY - maxRadius * postureScore,
    );
    skillPaint.color = Colors.red.withOpacity(0.5);
    canvas.drawCircle(posturePoint, 8, skillPaint);
    
    // Bow (bottom right)
    final bowPoint = Offset(
      centerX + maxRadius * bowScore * 0.866, // cos(30°) = 0.866
      centerY + maxRadius * bowScore * 0.5,   // sin(30°) = 0.5
    );
    skillPaint.color = Colors.blue.withOpacity(0.5);
    canvas.drawCircle(bowPoint, 8, skillPaint);
    
    // Rhythm (bottom left)
    final rhythmPoint = Offset(
      centerX - maxRadius * rhythmScore * 0.866, // -cos(30°)
      centerY + maxRadius * rhythmScore * 0.5,   // sin(30°)
    );
    skillPaint.color = Colors.green.withOpacity(0.5);
    canvas.drawCircle(rhythmPoint, 8, skillPaint);
    
    // Connect the points
    final linePaint = Paint()
      ..color = Colors.purple.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(posturePoint.dx, posturePoint.dy)
      ..lineTo(bowPoint.dx, bowPoint.dy)
      ..lineTo(rhythmPoint.dx, rhythmPoint.dy)
      ..close();
    
    canvas.drawPath(path, linePaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}