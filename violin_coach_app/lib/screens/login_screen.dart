import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  
  // Form controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // State variables
  bool _isRegistering = false;
  bool _isLoading = false;
  String? _errorMessage;
  UserRole _selectedRole = UserRole.student;
  
  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _login() async {
    // Validate inputs
    if (_usernameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your username or email';
      });
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final result = await _authService.login(
        usernameOrEmail: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      
      if (!result['success']) {
        setState(() {
          _errorMessage = result['message'];
          _isLoading = false;
        });
      }
      // If success, the auth state will change and navigate automatically
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _register() async {
    // Validate inputs
    if (_usernameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a username';
      });
      return;
    }
    
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an email';
      });
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a password';
      });
      return;
    }
    
    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final result = await _authService.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        displayName: _usernameController.text.trim(),
      );
      
      if (result['success']) {
        // Registration successful, login automatically
        await _authService.login(
          usernameOrEmail: _usernameController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        setState(() {
          _errorMessage = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              const Icon(
                Icons.music_note,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Violin Coach',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Master your violin technique with AI assistance',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              
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
              
              // Username/Email field
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: _isRegistering ? 'Username' : 'Username or Email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              
              // Email field (only for registration)
              if (_isRegistering) ...[
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
              ],
              
              // Password field
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                textInputAction: TextInputAction.done,
                enabled: !_isLoading,
                onSubmitted: (_) {
                  _isRegistering ? _register() : _login();
                },
              ),
              const SizedBox(height: 16),
              
              // Role selection (only for registration)
              if (_isRegistering) ...[
                const Text(
                  'I am a:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _RoleSelectionCard(
                        title: 'Student',
                        icon: Icons.school,
                        isSelected: _selectedRole == UserRole.student,
                        onTap: () {
                          setState(() {
                            _selectedRole = UserRole.student;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleSelectionCard(
                        title: 'Teacher',
                        icon: Icons.music_note,
                        isSelected: _selectedRole == UserRole.teacher,
                        onTap: () {
                          setState(() {
                            _selectedRole = UserRole.teacher;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              // Submit button
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        _isRegistering ? _register() : _login();
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isRegistering ? 'Register' : 'Login'),
              ),
              const SizedBox(height: 16),
              
              // Switch between login and register
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isRegistering = !_isRegistering;
                          _errorMessage = null;
                        });
                      },
                child: Text(_isRegistering
                    ? 'Already have an account? Login'
                    : 'Don\'t have an account? Register'),
              ),
              
              // Demo accounts section
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Demo Accounts',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _DemoAccountButton(
                label: 'Login as Teacher',
                onPressed: _isLoading
                    ? null
                    : () {
                        _usernameController.text = 'teacher';
                        _passwordController.text = 'password';
                        _login();
                      },
              ),
              const SizedBox(height: 8),
              _DemoAccountButton(
                label: 'Login as Student',
                onPressed: _isLoading
                    ? null
                    : () {
                        _usernameController.text = 'student';
                        _passwordController.text = 'password';
                        _login();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleSelectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _RoleSelectionCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.blue : Colors.grey,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blue : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoAccountButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  
  const _DemoAccountButton({
    required this.label,
    required this.onPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label),
    );
  }
}