import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Client Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF6366F1),
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF8B5CF6),
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: AccountsClientsPage(),
    );
  }
}

class AccountsClientsPage extends StatefulWidget {
  @override
  State<AccountsClientsPage> createState() => _AccountsClientsPageState();
}

class _AccountsClientsPageState extends State<AccountsClientsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _paidController = TextEditingController();
  final _freeController = TextEditingController();
  final _priceController = TextEditingController(text: '17');
  final _notesController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> clients = [];
  List<Map<String, dynamic>> filteredClients = [];
  Map<String, dynamic>? selectedClient;
  int selectedIndex = -1;
  String selectedPeriod = '1 Month';
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final prefs = await SharedPreferences.getInstance();
    final clientsJson = prefs.getString('clients_v2');
    
    if (clientsJson != null) {
      final List<dynamic> decoded = json.decode(clientsJson);
      setState(() {
        clients = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        filteredClients = List.from(clients);
      });
    }
  }

  Future<void> _saveClients() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clients_v2', json.encode(clients));
  }

  void _filterClients(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredClients = List.from(clients);
      } else {
        filteredClients = clients.where((client) {
          return client['name'].toLowerCase().contains(query.toLowerCase()) ||
                 client['phone'].contains(query);
        }).toList();
      }
    });
  }

  double _calculateTotal() {
    final paid = int.tryParse(_paidController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    return paid * price;
  }

  double _calculatePeriodTotal() {
    final monthlyTotal = _calculateTotal();
    switch (selectedPeriod) {
      case '6 Months':
        return monthlyTotal * 6;
      case '1 Year':
        return monthlyTotal * 12;
      default: // 1 Month
        return monthlyTotal;
    }
  }

  void _addClient() {
    if (_formKey.currentState!.validate()) {
      final monthlyTotal = _calculateTotal();
      final periodTotal = _calculatePeriodTotal();
      
      final newClient = {
        'name': _nameController.text,
        'phone': _phoneController.text,
        'paid': _paidController.text,
        'free': _freeController.text,
        'price': _priceController.text,
        'monthlyTotal': monthlyTotal.toStringAsFixed(2),
        'periodTotal': periodTotal.toStringAsFixed(2),
        'period': selectedPeriod,
        'notes': _notesController.text,
        'expiryDate': _expiryDateController.text,
      };

      setState(() {
        clients.add(newClient);
        filteredClients = List.from(clients);
        selectedClient = newClient;
        selectedIndex = clients.length - 1;
      });

      _saveClients();
      _clearForm();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Client added successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _updateClient() {
    if (_formKey.currentState!.validate() && selectedClient != null) {
      final monthlyTotal = _calculateTotal();
      final periodTotal = _calculatePeriodTotal();
      
      final updatedClient = {
        'name': _nameController.text,
        'phone': _phoneController.text,
        'paid': _paidController.text,
        'free': _freeController.text,
        'price': _priceController.text,
        'monthlyTotal': monthlyTotal.toStringAsFixed(2),
        'periodTotal': periodTotal.toStringAsFixed(2),
        'period': selectedPeriod,
        'notes': _notesController.text,
        'expiryDate': _expiryDateController.text,
      };

      setState(() {
        clients[selectedIndex] = updatedClient;
        filteredClients = List.from(clients);
        selectedClient = updatedClient;
        _isEditing = false;
      });

      _saveClients();
      _clearForm();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Client updated successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _paidController.clear();
    _freeController.clear();
    _priceController.text = '17';
    _notesController.clear();
    _expiryDateController.clear();
    setState(() {
      selectedPeriod = '1 Month';
      _isEditing = false;
    });
  }

  void _selectClient(int index) {
    setState(() {
      selectedIndex = index;
      selectedClient = clients[index];
    });
    
    // Auto-show details on mobile when client is selected
    if (MediaQuery.of(context).size.width <= 900) {
      _showClientDetails(context);
    }
  }

  void _editClient() {
    if (selectedClient != null) {
      setState(() {
        _isEditing = true;
      });
      
      _nameController.text = selectedClient!['name'];
      _phoneController.text = selectedClient!['phone'];
      _paidController.text = selectedClient!['paid'] ?? '';
      _freeController.text = selectedClient!['free'] ?? '';
      _priceController.text = selectedClient!['price'] ?? '17';
      _notesController.text = selectedClient!['notes'] ?? '';
      _expiryDateController.text = selectedClient!['expiryDate'];
      selectedPeriod = selectedClient!['period'] ?? '1 Month';
    }
  }

  void _cancelEdit() {
    _clearForm();
    if (MediaQuery.of(context).size.width <= 900) {
      Navigator.of(context).pop();
    }
  }

  void _deleteClient(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(child: Text('Delete Client')),
          ],
        ),
        content: Text('Are you sure you want to delete ${clients[index]['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                clients.removeAt(index);
                filteredClients = List.from(clients);
                if (selectedIndex == index) {
                  selectedIndex = -1;
                  selectedClient = null;
                  _isEditing = false;
                } else if (selectedIndex > index) {
                  selectedIndex--;
                }
              });
              _saveClients();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Client deleted successfully!'),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getReminderMessage() {
    if (selectedClient == null) return '';
    
    final expiryDate = DateTime.tryParse(selectedClient!['expiryDate']);
    if (expiryDate == null) return '';
    
    final now = DateTime.now();
    final daysRemaining = expiryDate.difference(now).inDays;
    
    if (daysRemaining <= 0) {
      return "Hello ${selectedClient!['name']},\n\n"
             "Your account has expired on ${selectedClient!['expiryDate']}.\n\n"
             "We hope you enjoyed our services! To continue enjoying uninterrupted access, "
             "please contact us to reactivate your subscription.\n\n"
             "📱 Contact us today to renew!\n\n"
             "Thank you for being a valued client.";
    } else if (daysRemaining <= 30) {
      return "Hello ${selectedClient!['name']},\n\n"
             "This is a friendly reminder that your account will expire in *$daysRemaining days* "
             "on ${selectedClient!['expiryDate']}.\n\n"
             "To avoid any interruption in service, please renew your subscription soon.\n\n"
             "📞 Contact us for quick renewal!\n\n"
             "Thank you for your continued trust.";
    }
    
    return "Hello ${selectedClient!['name']},\n\n"
           "Thank you for being a valued client! Your account is active and will remain valid "
           "until ${selectedClient!['expiryDate']} ($daysRemaining days remaining).\n\n"
           "We're here to serve you!";
  }

  String _formatPhoneNumber(String phone) {
    if (phone.isEmpty) return '';
    
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    print('Original digits: $digits');
    
    // Remove any leading zeros first
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    
    print('After removing zeros: $digits');
    
    // Check if it's already a complete international number
    if (digits.startsWith('961') && digits.length == 11) {
      return digits;
    }
    
    // Handle Lebanese numbers
    if (digits.length == 8) {
      // Check if it's a valid Lebanese mobile prefix
      final firstTwo = digits.substring(0, 2);
      final firstOne = digits.substring(0, 1);
      
      if (firstTwo == '70' || firstTwo == '71' || firstTwo == '76' || 
          firstTwo == '78' || firstTwo == '79' || firstTwo == '81') {
        return '961$digits';
      } else if (firstOne == '3') {
        return '961$digits';
      }
    } else if (digits.length == 7) {
      // Handle numbers like 3123456 (without leading 0)
      final firstOne = digits.substring(0, 1);
      if (firstOne == '3') {
        return '961$digits';
      }
    }
    
    // If we can't format properly, return the cleaned digits
    return digits;
  }

  Future<void> _sendWhatsAppMessage() async {
    if (selectedClient == null) return;
    
    final message = _getReminderMessage();
    String phone = _formatPhoneNumber(selectedClient!['phone']);
    
    print('Original phone: ${selectedClient!['phone']}');
    print('Formatted phone: $phone');
    
    // Ensure phone starts with country code
    if (!phone.startsWith('961')) {
      if (phone.length == 8) {
        phone = '961$phone';
      } else {
        // Show error for invalid format
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invalid phone number format'),
                      SizedBox(height: 4),
                      Text(
                        'Original: ${selectedClient!['phone']}',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Formatted: $phone',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Please use Lebanese format: 03xxxxxx, 70xxxxxx, etc.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
    }
    
    // Clean the phone number for WhatsApp URL
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    print('Final phone for WhatsApp: $cleanPhone');
    
    // Use wa.me URL format (more reliable)
    final url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
    
    print('WhatsApp URL: $url');
    
    try {
      final uri = Uri.parse(url);
      
      // Try to launch directly without canLaunchUrl check (it's often problematic)
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        throw 'Could not launch WhatsApp';
      }
      
    } catch (e) {
      print('WhatsApp error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Could not launch WhatsApp'),
                    SizedBox(height: 4),
                    Text(
                      'Phone: ${selectedClient!['phone']} → $cleanPhone',
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Error: $e',
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Make sure WhatsApp is installed and the number is correct.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _exportToExcel() async {
    try {
      var excel = excel_lib.Excel.createExcel();
      var sheet = excel['Clients'];
      
      sheet.appendRow([
        'Client Name',
        'Phone Number',
        'Paid Phones',
        'Free Phones',
        'Price per Phone',
        'Total/Month',
        'Period',
        'Total for Period',
        'Expiry Date',
        'Status',
        'Days Remaining',
        'Notes'
      ]);
      
      for (var client in clients) {
        final expiryDate = DateTime.tryParse(client['expiryDate']);
        final daysRemaining = expiryDate?.difference(DateTime.now()).inDays ?? 0;
        final status = daysRemaining <= 0 ? 'EXPIRED' : 
                      daysRemaining <= 30 ? 'EXPIRING SOON' : 'ACTIVE';
        
        sheet.appendRow([
          client['name'],
          client['phone'],
          client['paid'] ?? '',
          client['free'] ?? '',
          client['price'] ?? '',
          client['monthlyTotal'] ?? '',
          client['period'] ?? '',
          client['periodTotal'] ?? '',
          client['expiryDate'],
          status,
          daysRemaining.toString(),
          client['notes'] ?? ''
        ]);
      }
      
      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/clients_export_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Client List Export',
          text: 'Client management data exported on ${DateTime.now().toString().split(' ')[0]}',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Excel file exported successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Export failed: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _expiryDateController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  void _showClientDetails(BuildContext context) {
    if (selectedClient == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Client Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            onPressed: _editClient,
                            tooltip: 'Edit Client',
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildClientDetailsContent(scrollController),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildClientDetailsContent(ScrollController? scrollController) {
    if (selectedClient == null) return SizedBox();
    
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Text(
                  selectedClient!['name'][0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedClient!['name'],
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      selectedClient!['phone'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildExpiryStatus(),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildDetailRow(Icons.phone_android, 'Paid Phones', selectedClient!['paid'] ?? '0'),
                Divider(),
                _buildDetailRow(Icons.card_giftcard, 'Free Phones', selectedClient!['free'] ?? '0'),
                Divider(),
                _buildDetailRow(Icons.attach_money, 'Price per Phone', '\$${selectedClient!['price'] ?? '0'}'),
                Divider(),
                _buildDetailRow(Icons.money, 'Total per Month', '\$${selectedClient!['monthlyTotal'] ?? '0'}', isHighlight: true),
                Divider(),
                _buildDetailRow(Icons.money, 'Total for ${selectedClient!['period']}', '\$${selectedClient!['periodTotal'] ?? '0'}', isHighlight: true),
                Divider(),
                _buildDetailRow(Icons.timer, 'Period', selectedClient!['period'] ?? 'N/A'),
                Divider(),
                _buildDetailRow(Icons.calendar_today, 'Expiry Date', selectedClient!['expiryDate']),
                if (selectedClient!['notes'] != null && selectedClient!['notes'].toString().isNotEmpty) ...[
                  Divider(),
                  _buildDetailRow(Icons.note, 'Notes', selectedClient!['notes']),
                ],
              ],
            ),
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.message, color: Color(0xFF25D366)),
                    SizedBox(width: 8),
                    Text(
                      'WhatsApp Message:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  _getReminderMessage(),
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _sendWhatsAppMessage,
              icon: Icon(Icons.chat),
              label: Text('Send WhatsApp Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Client Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.file_download),
            onPressed: clients.isEmpty ? null : _exportToExcel,
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: isDesktop 
          ? _buildDesktopLayout()
          : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildAddClientForm(),
                SizedBox(height: 16),
                Expanded(child: _buildClientsList()),
              ],
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: selectedClient != null
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Client Details',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit, color: Colors.blue),
                                      onPressed: _editClient,
                                      tooltip: 'Edit Client',
                                    ),
                                    if (_isEditing)
                                      IconButton(
                                        icon: Icon(Icons.close, color: Colors.red),
                                        onPressed: _cancelEdit,
                                        tooltip: 'Cancel Edit',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _buildClientDetailsContent(null),
                          ),
                        ],
                      ),
                    ),
                  )
                : Card(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search, size: 80, color: Colors.grey[300]),
                          SizedBox(height: 16),
                          Text(
                            'Select a client to view details',
                            style: TextStyle(color: Colors.grey[400], fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildAddClientForm(),
                SizedBox(height: 16),
                _buildClientsList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddClientForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isEditing ? Icons.edit : Icons.person_add, 
                      color: Theme.of(context).colorScheme.primary
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Edit Client' : 'Add New Client', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                  if (_isEditing) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Editing',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Client Name *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter client name' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  hintText: '03 123 456 or 71 123 456',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.isEmpty ? 'Please enter phone number' : null,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _paidController,
                      decoration: InputDecoration(
                        labelText: 'Paid',
                        prefixIcon: Icon(Icons.phone_android),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _freeController,
                      decoration: InputDecoration(
                        labelText: 'Free',
                        prefixIcon: Icon(Icons.card_giftcard),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price (\$) *',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => setState(() {}),
                validator: (value) => value == null || value.isEmpty ? 'Please enter price' : null,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total per Month:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '\$${_calculateTotal().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total for $selectedPeriod:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '\$${_calculatePeriodTotal().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPeriod,
                decoration: InputDecoration(
                  labelText: 'Period *',
                  prefixIcon: Icon(Icons.timer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: ['1 Month', '6 Months', '1 Year'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedPeriod = newValue!;
                  });
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _expiryDateController,
                decoration: InputDecoration(
                  labelText: 'Expiry Date *',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (value) => value == null || value.isEmpty ? 'Please select expiry date' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 2,
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  if (_isEditing) ...[
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _cancelEdit,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Cancel', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: _isEditing ? 1 : 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isEditing ? _updateClient : _addClient,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _isEditing ? 'Update Client' : 'Add Client', 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                      ),
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

  Widget _buildClientsList() {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: Theme.of(context).colorScheme.secondary),
                    SizedBox(width: 12),
                    Text('Clients', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${clients.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: _filterClients,
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Container(
            height: 400,
            child: filteredClients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text(
                          clients.isEmpty ? 'No clients yet' : 'No results found',
                          style: TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(8),
                    itemCount: filteredClients.length,
                    itemBuilder: (context, index) {
                      final client = filteredClients[index];
                      final actualIndex = clients.indexOf(client);
                      final expiryDate = DateTime.tryParse(client['expiryDate']);
                      final isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());
                      final daysRemaining = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : 0;
                      final isExpiringSoon = daysRemaining <= 30 && daysRemaining > 0;

                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        color: selectedIndex == actualIndex
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: selectedIndex == actualIndex
                              ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: isExpired
                                ? Colors.red.withOpacity(0.1)
                                : isExpiringSoon
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                            child: Text(
                              client['name'][0].toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isExpired ? Colors.red : isExpiringSoon ? Colors.orange : Colors.green,
                              ),
                            ),
                          ),
                          title: Text(client['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(client['phone'], style: TextStyle(fontSize: 12)),
                              SizedBox(height: 4),
                              if (isExpired)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('EXPIRED', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                              else if (isExpiringSoon)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('$daysRemaining days', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _deleteClient(actualIndex),
                          ),
                          onTap: () => _selectClient(actualIndex),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                fontSize: isHighlight ? 16 : 13,
                color: isHighlight ? Theme.of(context).colorScheme.primary : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryStatus() {
    if (selectedClient == null) return SizedBox();
    
    final expiryDate = DateTime.tryParse(selectedClient!['expiryDate']);
    if (expiryDate == null) return SizedBox();
    
    final now = DateTime.now();
    final daysRemaining = expiryDate.difference(now).inDays;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (daysRemaining <= 0) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'EXPIRED';
    } else if (daysRemaining <= 30) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'EXPIRING SOON ($daysRemaining days)';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'ACTIVE ($daysRemaining days)';
    }
    
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _paidController.dispose();
    _freeController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _expiryDateController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}