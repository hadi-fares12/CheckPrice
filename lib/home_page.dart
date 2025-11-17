import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'import_excel_page.dart';
import 'check_price_page.dart';
import 'edit_stock_page.dart';
import 'export_excel_page.dart';
import 'settings_page.dart';
import 'create_invoice_page.dart';
import 'accounts_clients_page.dart'; // Import the new page

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isAdmin = false;
  String username = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isAdmin = prefs.getBool('isAdmin') ?? false;
      username = prefs.getString('username') ?? '';
    });

    // Check expiry for non-admin users after loading
    if (!isAdmin) {
      _checkAccountExpiry();
    }
  }

  // Check account expiry and show warning if needed
  Future<void> _checkAccountExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final userAccounts = prefs.getStringList('userAccounts') ?? [];
    final userExpiryDates = prefs.getStringList('userExpiryDates') ?? [];

    // Find current user's expiry date
    for (int i = 0; i < userAccounts.length; i++) {
      final accountData = userAccounts[i].split(':');
      if (accountData.length == 2) {
        final storedUsername = accountData[0];

        if (username == storedUsername) {
          if (i < userExpiryDates.length) {
            final expiryDateStr = userExpiryDates[i];
            if (expiryDateStr.isNotEmpty) {
              try {
                final expiryDate = DateTime.parse(expiryDateStr);
                final now = DateTime.now();
                final daysRemaining = expiryDate.difference(now).inDays;

                // Show warning if expiring within 30 days
                if (daysRemaining <= 30 && daysRemaining > 0) {
                  // Delay to ensure the page is fully built
                  Future.delayed(Duration(milliseconds: 500), () {
                    if (mounted) {
                      _showExpiryWarningDialog(daysRemaining);
                    }
                  });
                }
              } catch (e) {
                // Invalid date format
              }
            }
          }
          break;
        }
      }
    }
  }

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

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home - $username'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsPage()),
              ),
            ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _HomeCard(
              icon: Icons.upload_file,
              label: 'Import Excel',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ImportExcelPage()),
              ),
            ),
            _HomeCard(
              icon: Icons.search,
              label: 'Check Price',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CheckPricePage()),
              ),
            ),
            _HomeCard(
              icon: Icons.edit,
              label: 'Edit Stock',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditStockPage()),
              ),
            ),
            _HomeCard(
              icon: Icons.download,
              label: 'Export Excel',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ExportExcelPage()),
              ),
            ),
            _HomeCard(
              icon: Icons.receipt,
              label: 'Create Invoice',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateInvoicePage()),
              ),
            ),
            // New Accounts Clients button - only visible to admin
            if (isAdmin)
              _HomeCard(
                icon: Icons.people,
                label: 'Accounts Clients',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AccountsClientsPage()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HomeCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color cardColor;
    switch (label) {
      case 'Import Excel':
        cardColor = colorScheme.primary.withOpacity(0.9);
        break;
      case 'Check Price':
        cardColor = colorScheme.secondary.withOpacity(0.9);
        break;
      case 'Edit Stock':
        cardColor = Color(0xFF4CAF50).withOpacity(0.9);
        break;
      case 'Export Excel':
        cardColor = Color(0xFFF44336).withOpacity(0.9);
        break;
      case 'Create Invoice':
        cardColor = Color(0xFF9C27B0).withOpacity(0.9);
        break;
      case 'Accounts Clients':
        cardColor = Color(0xFFFF9800).withOpacity(0.9); // Orange color for Accounts Clients
        break;
      default:
        cardColor = colorScheme.primary;
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              SizedBox(height: 16),
              Text(
                label, 
                style: TextStyle(
                  fontSize: 18, 
                  color: Colors.white, 
                  fontWeight: FontWeight.bold
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}