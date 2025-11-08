import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  // Admin accounts
  static const Map<String, String> adminAccounts = {
    'katerji2025': '03089038',
    'maali': '81973930',
    'hadi': '70097279',
  };

  // Show expiry warning dialog
  void _showExpiryWarningDialog(int daysRemaining) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Account Expiring Soon!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: BoxConstraints(minHeight: 150),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.access_time, size: 48, color: Colors.orange.shade700),
                    SizedBox(height: 12),
                    Text(
                      '$daysRemaining ${daysRemaining == 1 ? 'Day' : 'Days'} Remaining',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Your account will expire soon. Please contact the administrator to reactivate your subscription.',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone, size: 18, color: Colors.blue.shade700),
                        SizedBox(width: 8),
                        Text(
                          'Contact Administrator:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _buildPhoneNumber('03089038'),
                    SizedBox(height: 4),
                    _buildPhoneNumber('70097279'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'I Understand',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Show account expired dialog
  void _showAccountExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Account Expired',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: BoxConstraints(minHeight: 150),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.block, size: 48, color: Colors.red.shade700),
                    SizedBox(height: 12),
                    Text(
                      'Access Denied',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Your account has expired and you can no longer access the application.',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
              SizedBox(height: 12),
              Text(
                'Please contact the administrator to renew your subscription and regain access.',
                style: TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone, size: 18, color: Colors.blue.shade700),
                        SizedBox(width: 8),
                        Text(
                          'Contact Administrator:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _buildPhoneNumber('03089038'),
                    SizedBox(height: 4),
                    _buildPhoneNumber('70097279'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _usernameController.clear();
                _passwordController.clear();
                _error = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneNumber(String phone) {
    return Row(
      children: [
        Icon(Icons.phone_android, size: 14, color: Colors.blue.shade700),
        SizedBox(width: 4),
        Text(
          phone,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Please enter username and password.';
        _loading = false;
      });
      return;
    }

    // Check if it's an admin account
    if (adminAccounts.containsKey(username) &&
        adminAccounts[username] == password) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', username);
      await prefs.setBool('isAdmin', true);
      await prefs.setString('userType', 'admin');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage()),
      );
      return;
    }

    // Check if it's a user account
    final prefs = await SharedPreferences.getInstance();
    final userAccounts = prefs.getStringList('userAccounts') ?? [];
    final userExpiryDates = prefs.getStringList('userExpiryDates') ?? [];

    for (int i = 0; i < userAccounts.length; i++) {
      final accountData = userAccounts[i].split(':');
      if (accountData.length == 2) {
        final storedUsername = accountData[0];
        final storedPassword = accountData[1];

        if (username == storedUsername && password == storedPassword) {
          // Check expiry date
          if (i < userExpiryDates.length) {
            final expiryDateStr = userExpiryDates[i];
            if (expiryDateStr.isNotEmpty) {
              try {
                final expiryDate = DateTime.parse(expiryDateStr);
                final now = DateTime.now();
                final daysRemaining = expiryDate.difference(now).inDays;

                // Account has expired
                if (now.isAfter(expiryDate)) {
                  setState(() {
                    _loading = false;
                  });
                  _showAccountExpiredDialog();
                  return;
                }

                // Account will expire within 30 days - show warning
                if (daysRemaining <= 30 && daysRemaining > 0) {
                  await prefs.setBool('isLoggedIn', true);
                  await prefs.setString('username', username);
                  await prefs.setBool('isAdmin', false);
                  await prefs.setString('userType', 'user');

                  // Navigate to home first
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => HomePage()),
                  );

                  // Then show warning dialog
                  Future.delayed(Duration(milliseconds: 500), () {
                    _showExpiryWarningDialog(daysRemaining);
                  });
                  return;
                }
              } catch (e) {
                // Invalid date format, continue
              }
            }
          }

          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('username', username);
          await prefs.setBool('isAdmin', false);
          await prefs.setString('userType', 'user');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomePage()),
          );
          return;
        }
      }
    }

    setState(() {
      _error = 'Invalid username or password.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 32),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.person),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.lock),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        obscureText: true,
                        onFieldSubmitted: (_) => _login(),
                      ),
                      SizedBox(height: 24),
                      if (_error != null) ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _loading
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}