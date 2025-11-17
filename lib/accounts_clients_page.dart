import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final _expiryDateController = TextEditingController();

  List<Map<String, dynamic>> clients = [];
  Map<String, dynamic>? selectedClient;
  int selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final prefs = await SharedPreferences.getInstance();
    final clientsData = prefs.getStringList('clients') ?? [];
    
    setState(() {
      clients = clientsData.map((clientStr) {
        final parts = clientStr.split('|');
        return {
          'name': parts[0],
          'phone': parts[1],
          'paid': parts[2],
          'free': parts[3],
          'expiryDate': parts[4],
        };
      }).toList();
    });
  }

  Future<void> _saveClients() async {
    final prefs = await SharedPreferences.getInstance();
    final clientsData = clients.map((client) {
      return '${client['name']}|${client['phone']}|${client['paid']}|${client['free']}|${client['expiryDate']}';
    }).toList();
    await prefs.setStringList('clients', clientsData);
  }

  void _addClient() {
    if (_formKey.currentState!.validate()) {
      final newClient = {
        'name': _nameController.text,
        'phone': _phoneController.text,
        'paid': _paidController.text,
        'free': _freeController.text,
        'expiryDate': _expiryDateController.text,
      };

      setState(() {
        clients.add(newClient);
        selectedClient = newClient;
        selectedIndex = clients.length - 1;
      });

      _saveClients();
      _clearForm();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Client added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _paidController.clear();
    _freeController.clear();
    _expiryDateController.clear();
  }

  void _selectClient(int index) {
    setState(() {
      selectedIndex = index;
      selectedClient = clients[index];
    });
  }

  void _deleteClient(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Client'),
        content: Text('Are you sure you want to delete ${clients[index]['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                clients.removeAt(index);
                if (selectedIndex == index) {
                  selectedIndex = -1;
                  selectedClient = null;
                } else if (selectedIndex > index) {
                  selectedIndex--;
                }
              });
              _saveClients();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Client deleted successfully!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
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
      return "Hello ${selectedClient!['name']}, your account has expired. Please contact us to reactivate your subscription and continue enjoying our services.";
    } else if (daysRemaining <= 30) {
      return "Hello ${selectedClient!['name']}, your account will expire in $daysRemaining days. Please renew your subscription to avoid interruption of service.";
    }
    
    return "Hello ${selectedClient!['name']}, this is a reminder about your account status.";
  }

  Future<void> _sendWhatsAppMessage() async {
    final message = _getReminderMessage();
    final phone = selectedClient!['phone'].replaceAll(RegExp(r'[^0-9]'), '');
    
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch WhatsApp'),
          backgroundColor: Colors.red,
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
        title: Text('Accounts Clients Details'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Form and Client List
            Expanded(
              flex: 2,
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
                              'Add New Client',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Client Name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter client name';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter phone number';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _paidController,
                                    decoration: InputDecoration(
                                      labelText: 'Paid Items',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter paid count';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _freeController,
                                    decoration: InputDecoration(
                                      labelText: 'Free Items',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter free count';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            TextFormField(
                              controller: _expiryDateController,
                              decoration: InputDecoration(
                                labelText: 'Expiry Date',
                                border: OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.calendar_today),
                                  onPressed: () => _selectDate(context),
                                ),
                              ),
                              readOnly: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select expiry date';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _addClient,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: Text('Add Client'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Clients List',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Expanded(
                              child: clients.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No clients added yet',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: clients.length,
                                      itemBuilder: (context, index) {
                                        final client = clients[index];
                                        final expiryDate = DateTime.tryParse(client['expiryDate']);
                                        final isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());
                                        final daysRemaining = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : 0;
                                        final isExpiringSoon = daysRemaining <= 30 && daysRemaining > 0;

                                        return Card(
                                          margin: EdgeInsets.symmetric(vertical: 4),
                                          color: selectedIndex == index
                                              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                              : null,
                                          child: ListTile(
                                            title: Text(
                                              client['name'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(client['phone']),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isExpiringSoon)
                                                  Icon(Icons.warning, color: Colors.orange, size: 20),
                                                if (isExpired)
                                                  Icon(Icons.error, color: Colors.red, size: 20),
                                                SizedBox(width: 8),
                                                IconButton(
                                                  icon: Icon(Icons.delete, color: Colors.red),
                                                  onPressed: () => _deleteClient(index),
                                                ),
                                              ],
                                            ),
                                            onTap: () => _selectClient(index),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            // Right side - Client Details
            Expanded(
              flex: 3,
              child: selectedClient != null
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Client Details',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (selectedClient != null)
                                  ElevatedButton.icon(
                                    onPressed: _sendWhatsAppMessage,
                                    icon: Icon(Icons.message),
                                    label: Text('Send WhatsApp'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 20),
                            _buildDetailRow('Name', selectedClient!['name']),
                            _buildDetailRow('Phone', selectedClient!['phone']),
                            _buildDetailRow('Paid Items', selectedClient!['paid']),
                            _buildDetailRow('Free Items', selectedClient!['free']),
                            _buildDetailRow('Expiry Date', selectedClient!['expiryDate']),
                            SizedBox(height: 20),
                            _buildExpiryStatus(),
                            SizedBox(height: 20),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'WhatsApp Message:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Text(
                                          _getReminderMessage(),
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Card(
                      child: Center(
                        child: Text(
                          'Select a client to view details',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: Text(value)),
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
      statusText = 'EXPIRING SOON ($daysRemaining days remaining)';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'ACTIVE ($daysRemaining days remaining)';
    }
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
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
    _expiryDateController.dispose();
    super.dispose();
  }
}