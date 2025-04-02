import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/classroom.dart';
import '../services/auth_service.dart';
import '../services/classroom_service.dart';
import 'package:provider/provider.dart';

class TeacherClassroomScreen extends StatefulWidget {
  const TeacherClassroomScreen({Key? key}) : super(key: key);

  @override
  State<TeacherClassroomScreen> createState() => _TeacherClassroomScreenState();
}

class _TeacherClassroomScreenState extends State<TeacherClassroomScreen> {
  int _selectedIndex = 0;
  
  final _pages = [
    const _ClassroomsPage(),
    const _ReviewRecordingsPage(),
    const _ProfilePage(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.class_),
            label: 'Classrooms',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Recordings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ClassroomsPage extends StatefulWidget {
  const _ClassroomsPage();

  @override
  State<_ClassroomsPage> createState() => _ClassroomsPageState();
}

class _ClassroomsPageState extends State<_ClassroomsPage> {
  final _classroomService = ClassroomService();
  List<Classroom> _classrooms = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }
  
  Future<void> _loadClassrooms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final classrooms = await _classroomService.getTeacherClassrooms();
      setState(() {
        _classrooms = classrooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load classrooms: $e';
        _isLoading = false;
      });
    }
  }
  
  void _showCreateClassroomDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Classroom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Classroom Name',
                hintText: 'e.g., Beginner Violin Class',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., For students learning Suzuki Book 1',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              
              Navigator.of(context).pop();
              
              try {
                await _classroomService.createClassroom(
                  name: nameController.text,
                  description: descriptionController.text,
                );
                _loadClassrooms();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to create classroom: $e')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classrooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Notification screen
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _classrooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.class_,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No classrooms yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Create your first classroom'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showCreateClassroomDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Classroom'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadClassrooms,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _classrooms.length,
                        itemBuilder: (context, index) {
                          final classroom = _classrooms[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => _ClassroomDetailPage(
                                      classroom: classroom,
                                    ),
                                  ),
                                ).then((_) => _loadClassrooms());
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.blue.shade100,
                                          child: const Icon(
                                            Icons.class_,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                classroom.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (classroom.description
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  classroom.description,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${classroom.studentCount} students',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Class Code: ${classroom.joinCode}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            // Share class code
                                          },
                                          icon: const Icon(Icons.share),
                                          label: const Text('Share Code'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _classrooms.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showCreateClassroomDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _ClassroomDetailPage extends StatefulWidget {
  final Classroom classroom;
  
  const _ClassroomDetailPage({required this.classroom});
  
  @override
  State<_ClassroomDetailPage> createState() => _ClassroomDetailPageState();
}

class _ClassroomDetailPageState extends State<_ClassroomDetailPage>
    with SingleTickerProviderStateMixin {
  final _classroomService = ClassroomService();
  late TabController _tabController;
  List<User> _students = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStudents();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final students = await _classroomService.getClassroomStudents(
        widget.classroom.id,
      );
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load students: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classroom.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Assignments'),
            Tab(text: 'Recordings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Students tab
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!))
                  : _students.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.people,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No students yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Share class code: ${widget.classroom.joinCode}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadStudents,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _students.length,
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green.shade100,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.green,
                                    ),
                                  ),
                                  title: Text(student.name),
                                  subtitle: Text(student.email),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    // Navigate to student details
                                  },
                                ),
                              );
                            },
                          ),
                        ),
          
          // Assignments tab
          const Center(
            child: Text('Assignments coming soon'),
          ),
          
          // Recordings tab
          const Center(
            child: Text('Recordings coming soon'),
          ),
        ],
      ),
    );
  }
}

class _ReviewRecordingsPage extends StatelessWidget {
  const _ReviewRecordingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Recordings'),
      ),
      body: const Center(
        child: Text('Student recordings coming soon'),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = Provider.of<User?>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            
            // Profile picture
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue,
              child: Icon(
                Icons.person,
                size: 50,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // User name
            Text(
              user?.name ?? 'Teacher',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Email
            Text(
              user?.email ?? 'teacher@example.com',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Teacher',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Stats cards
            Row(
              children: const [
                Expanded(
                  child: _StatCard(
                    title: 'Classrooms',
                    value: '3',
                    icon: Icons.class_,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Students',
                    value: '18',
                    icon: Icons.people,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: const [
                Expanded(
                  child: _StatCard(
                    title: 'Reviews',
                    value: '24',
                    icon: Icons.rate_review,
                    color: Colors.orange,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Feedback',
                    value: '93%',
                    icon: Icons.thumb_up,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Settings list
            const _SettingsItem(
              icon: Icons.notifications,
              title: 'Notifications',
            ),
            
            const _SettingsItem(
              icon: Icons.lock,
              title: 'Privacy',
            ),
            
            const _SettingsItem(
              icon: Icons.help,
              title: 'Help & Support',
            ),
            
            const _SettingsItem(
              icon: Icons.info,
              title: 'About',
            ),
            
            const SizedBox(height: 24),
            
            // Logout button
            ElevatedButton.icon(
              onPressed: () async {
                await authService.logout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  
  const _SettingsItem({
    required this.icon,
    required this.title,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // Navigate to settings screen
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}