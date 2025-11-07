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

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    
    if (username.isEmpty || password.isEmpty) {
      setState(() { _error = 'Please enter username and password.'; });
      setState(() { _loading = false; });
      return;
    }

    // Check if it's an admin account
    if (adminAccounts.containsKey(username) && adminAccounts[username] == password) {
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
                if (DateTime.now().isAfter(expiryDate)) {
                  setState(() { _error = 'Account has expired. Please contact administrator.'; });
                  setState(() { _loading = false; });
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
    
    setState(() { _error = 'Invalid username or password.'; });
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 24),
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: Colors.red)),
                  SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading ? CircularProgressIndicator(color: Colors.white) : Text('Login', style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 