import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _expiryDateController = TextEditingController();
  
  List<Map<String, String>> userAccounts = [];
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadUserAccounts();
  }

  Future<void> _loadUserAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final userAccountsList = prefs.getStringList('userAccounts') ?? [];
    final userExpiryDates = prefs.getStringList('userExpiryDates') ?? [];
    
    setState(() {
      userAccounts = [];
      for (int i = 0; i < userAccountsList.length; i++) {
        final accountData = userAccountsList[i].split(':');
        if (accountData.length == 2) {
          userAccounts.add({
            'username': accountData[0],
            'password': accountData[1],
            'expiryDate': i < userExpiryDates.length ? userExpiryDates[i] : '',
          });
        }
      }
    });
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _message = null; });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final expiryDate = _expiryDateController.text.trim();

    // Check if username already exists
    if (userAccounts.any((account) => account['username'] == username)) {
      setState(() { _message = 'Username already exists.'; });
      setState(() { _loading = false; });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userAccountsList = prefs.getStringList('userAccounts') ?? [];
    final userExpiryDates = prefs.getStringList('userExpiryDates') ?? [];

    userAccountsList.add('$username:$password');
    userExpiryDates.add(expiryDate);

    await prefs.setStringList('userAccounts', userAccountsList);
    await prefs.setStringList('userExpiryDates', userExpiryDates);

    _usernameController.clear();
    _passwordController.clear();
    _expiryDateController.clear();

    await _loadUserAccounts();
    setState(() { _message = 'User added successfully.'; });
    setState(() { _loading = false; });
  }

  Future<void> _deleteUser(int index) async {
    setState(() { _loading = true; });

    final prefs = await SharedPreferences.getInstance();
    final userAccountsList = prefs.getStringList('userAccounts') ?? [];
    final userExpiryDates = prefs.getStringList('userExpiryDates') ?? [];

    if (index < userAccountsList.length) {
      userAccountsList.removeAt(index);
      if (index < userExpiryDates.length) {
        userExpiryDates.removeAt(index);
      }

      await prefs.setStringList('userAccounts', userAccountsList);
      await prefs.setStringList('userExpiryDates', userExpiryDates);

      await _loadUserAccounts();
      setState(() { _message = 'User deleted successfully.'; });
    }

    setState(() { _loading = false; });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _expiryDateController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings - User Management'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New User',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter username';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter password';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expiryDateController,
                              decoration: InputDecoration(
                                labelText: 'Expiry Date (Optional)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.calendar_today),
                                  onPressed: _selectDate,
                                ),
                              ),
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _addUser,
                          child: _loading ? CircularProgressIndicator(color: Colors.white) : Text('Add User'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            if (_message != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _message!.contains('successfully') ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.contains('successfully') ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'User Accounts',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    height: 300, // Fixed height for the user list
                    child: ListView.builder(
                      itemCount: userAccounts.length,
                      itemBuilder: (context, index) {
                        final account = userAccounts[index];
                        final expiryDate = account['expiryDate'];
                        final isExpired = expiryDate != null && expiryDate.isNotEmpty
                            ? DateTime.now().isAfter(DateTime.parse(expiryDate))
                            : false;
                        
                        return ListTile(
                          title: Text(account['username'] ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Password: ${account['password'] ?? ''}'),
                              if (expiryDate != null && expiryDate.isNotEmpty)
                                Text(
                                  'Expires: $expiryDate',
                                  style: TextStyle(
                                    color: isExpired ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteUser(index),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20), // Add bottom padding for scroll
          ],
        ),
      ),
    );
  }
} 