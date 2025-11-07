import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'import_excel_page.dart';
import 'check_price_page.dart';
import 'edit_stock_page.dart';
import 'export_excel_page.dart';
import 'settings_page.dart';
import 'create_invoice_page.dart';

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
             _HomeCard( // Add this new card
      icon: Icons.receipt,
      label: 'Create Invoice',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CreateInvoicePage()),
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
      case 'Create Invoice': // Add this case
        cardColor = Color(0xFF9C27B0).withOpacity(0.9);
        break;
      default:
        cardColor = colorScheme.primary;
    }
    return Card(
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
              Text(label, style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
} 