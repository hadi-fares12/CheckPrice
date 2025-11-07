import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EditStockPage extends StatefulWidget {
  @override
  State<EditStockPage> createState() => _EditStockPageState();
}

class _EditStockPageState extends State<EditStockPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _foundRows = [];
  Set<String> _selectedColumns = {};
  Map<String, TextEditingController> _editControllers = {};
  bool _showAddRow = false;
  Map<String, dynamic>? _newRow;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<DataProvider>(context, listen: false);
    if (_selectedColumns.isEmpty && provider.columns.isNotEmpty) {
      setState(() {
        _selectedColumns = Set<String>.from(provider.columns);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _clearEditControllers();
    super.dispose();
  }

  void _clearEditControllers() {
    for (var controller in _editControllers.values) {
      controller.dispose();
    }
    _editControllers.clear();
  }

  void _search(BuildContext context) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    final results = provider.search(query);
    setState(() { 
      _foundRows = results; 
    });
    
    // Auto-open dialog if only one item found
    if (results.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEditDialog(results.first, context);
      });
    }
  }

  void _scanBarcode(BuildContext context) async {
    String? scanned;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Scan Barcode'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: MobileScanner(
            onDetect: (capture) {
              final barcode = capture.barcodes.first.rawValue;
              if (barcode != null && barcode.isNotEmpty) {
                scanned = barcode;
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      ),
    );
    if (scanned != null) {
      _searchController.text = scanned!;
      _search(context);
    }
  }

  // Copy Dataset Functionality
  Future<void> _copyDataset(BuildContext context) async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    if (provider.selectedName == null) return;

    final controller = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Copy Dataset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Copy "${provider.selectedName}" as:'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'New dataset name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'e.g., ${provider.selectedName} Copy',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: Text('Copy'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      if (provider.datasetNames.contains(newName)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A dataset with this name already exists.')),
        );
        return;
      }
      await provider.copyDataset(provider.selectedName!, newName);
      
      // Clear current state after copying
      setState(() {
        _foundRows.clear();
        _selectedColumns = Set<String>.from(provider.columns);
        _showAddRow = false;
        _newRow = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dataset copied successfully!')),
      );
    }
  }

  // Delete Dataset Functionality
  Future<void> _deleteDataset(BuildContext context) async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    if (provider.selectedName == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Dataset'),
        content: Text('Are you sure you want to delete "${provider.selectedName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteDataset(provider.selectedName!);
      // Clear state after deletion
      setState(() {
        _foundRows.clear();
        _selectedColumns.clear();
        _showAddRow = false;
        _newRow = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dataset deleted successfully!')),
      );
    }
  }

  // Edit Column Names Functionality
  void _showEditColumnsDialog(BuildContext context) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final columnControllers = provider.columns.map((col) => 
      TextEditingController(text: col)
    ).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Column Names'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: columnControllers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: TextField(
                  controller: columnControllers[index],
                  decoration: InputDecoration(
                    labelText: 'Column ${index + 1}',
                    border: OutlineInputBorder(),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newColumns = columnControllers.map((c) => c.text.trim()).toList();
              if (newColumns.every((col) => col.isNotEmpty)) {
                _updateColumnNames(context, newColumns);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('All column names must be filled')),
                );
              }
            },
            child: Text('Save Columns'),
          ),
        ],
      ),
    );
  }

  void _updateColumnNames(BuildContext context, List<String> newColumns) async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    await provider.updateColumns(newColumns);
    
    // Update the selected columns to the new columns
    setState(() {
      _selectedColumns = Set<String>.from(newColumns);
    });
  }

  void _showEditDialog(Map<String, dynamic> item, BuildContext context) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    // Create controllers for each selected column
    _clearEditControllers();
    for (var col in _selectedColumns) {
      _editControllers[col] = TextEditingController(
        text: item[col]?.toString() ?? ''
      );
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: 8),
                Text('Edit Item'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display selected columns as editable fields
                  ..._selectedColumns.map((col) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            col,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: 4),
                          TextField(
                            controller: _editControllers[col],
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _clearEditControllers();
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _saveItem(context, item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: Text('Save', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => _showDeleteConfirmation(context, item),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: Text('Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMultipleItemsDialog(BuildContext context) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 8),
            Text('Select Item to Edit (${_foundRows.length} found)'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _foundRows.length,
            itemBuilder: (context, index) {
              final item = _foundRows[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                elevation: 1,
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    _getItemDisplayText(item, _selectedColumns.take(2).toList()),
                    style: TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: _getItemDisplayText(item, _selectedColumns.skip(2).take(2).toList()).isNotEmpty
                      ? Text(
                          _getItemDisplayText(item, _selectedColumns.skip(2).take(2).toList()),
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showEditDialog(item, context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getItemDisplayText(Map<String, dynamic> item, List<String> columns) {
    List<String> values = [];
    for (var col in columns) {
      final value = item[col]?.toString() ?? '';
      if (value.isNotEmpty) {
        values.add(value);
      }
    }
    return values.isEmpty ? 'No data' : values.join(' - ');
  }

  Future<void> _saveItem(BuildContext context, Map<String, dynamic> originalItem) async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    // Find the index of the original item
    final index = provider.rows.indexOf(originalItem);
    if (index == -1) return;
    
    // Create updated item from controllers
    final updatedItem = Map<String, dynamic>.from(originalItem);
    for (var col in _selectedColumns) {
      if (_editControllers[col] != null) {
        updatedItem[col] = _editControllers[col]!.text;
      }
    }
    
    await provider.updateRow(index, updatedItem);
    Navigator.of(context).pop();
    _clearEditControllers();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Item updated successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item'),
        content: Text('Are you sure you want to delete this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteItem(context, item),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, Map<String, dynamic> item) async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final index = provider.rows.indexOf(item);
    
    if (index != -1) {
      await provider.deleteRow(index);
      Navigator.of(context).pop(); // Close delete confirmation
      Navigator.of(context).pop(); // Close edit dialog
      _clearEditControllers();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item deleted successfully!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddItemDialog(BuildContext context) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    // Create controllers for new item
    _clearEditControllers();
    for (var col in _selectedColumns) {
      _editControllers[col] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.add, color: Colors.green),
                SizedBox(width: 8),
                Text('Add New Item'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._selectedColumns.map((col) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            col,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: 4),
                          TextField(
                            controller: _editControllers[col],
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _clearEditControllers();
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _addNewItem(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('Add Item', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addNewItem(BuildContext context) async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    // Create new item from controllers
    final newItem = <String, dynamic>{};
    for (var col in _selectedColumns) {
      if (_editControllers[col] != null) {
        newItem[col] = _editControllers[col]!.text;
      }
    }
    
    await provider.addRow(newItem);
    Navigator.of(context).pop();
    _clearEditControllers();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Item added successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final theme = Theme.of(context);
    
    if (provider.datasetNames.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Edit Stock'),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                'No Excel datasets available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
              SizedBox(height: 8),
              Text(
                'Please import an Excel file first',
                style: TextStyle(color: Colors.grey.shade500),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.upload_file),
                label: Text('Go to Import'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Stock'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (provider.selectedName != null) ...[
            IconButton(
              icon: Icon(Icons.edit_attributes),
              onPressed: () => _showEditColumnsDialog(context),
              tooltip: 'Edit Column Names',
            ),
            IconButton(
              icon: Icon(Icons.copy),
              onPressed: () => _copyDataset(context),
              tooltip: 'Copy Dataset',
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _deleteDataset(context),
              tooltip: 'Delete Dataset',
            ),
          ],
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Dataset Selection
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Select Dataset', Icons.folder, theme.colorScheme.primary),
                      DropdownButtonFormField<String>(
                        value: provider.selectedName,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: provider.datasetNames.map((name) {
                          return DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            provider.selectDataset(value);
                            setState(() {
                              _selectedColumns = Set<String>.from(provider.columns);
                              _foundRows.clear();
                            });
                          }
                        },
                      ),
                      if (provider.selectedName != null) ...[
                        SizedBox(height: 8),
                        Text(
                          '${provider.rows.length} items, ${provider.columns.length} columns',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              
              // Column selector
              if (provider.columns.isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Select Columns to Edit', Icons.view_column, theme.colorScheme.secondary),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: provider.columns.map((col) => FilterChip(
                            label: Text(col),
                            selected: _selectedColumns.contains(col),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedColumns.add(col);
                                } else {
                                  _selectedColumns.remove(col);
                                }
                              });
                            },
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 16),
              
              // Search Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildSectionHeader('Search Items', Icons.search, Colors.green),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: 'Search any field',
                                hintText: 'Enter search term or barcode...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              onSubmitted: (_) => _search(context),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
                              ),
                            ),
                            child: IconButton(
                              onPressed: () => _search(context),
                              icon: Icon(Icons.search, color: Colors.white),
                              tooltip: 'Search',
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [theme.colorScheme.secondary, theme.colorScheme.secondary.withOpacity(0.8)],
                              ),
                            ),
                            child: IconButton(
                              onPressed: () => _scanBarcode(context),
                              icon: Icon(Icons.qr_code_scanner, color: Colors.white),
                              tooltip: 'Scan Barcode',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      // Action Cards
                      Row(
                        children: [
                          _buildActionCard(
                            title: 'Add New Item',
                            subtitle: 'Add new item to inventory',
                            icon: Icons.add_circle_outline,
                            color: Color(0xFFFF9800),
                            onTap: () => _showAddItemDialog(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              
              // Search Results
              if (_foundRows.isNotEmpty && _foundRows.length > 1)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Search Results (${_foundRows.length} found)', Icons.search, theme.colorScheme.primary),
                        SizedBox(height: 12),
                        Container(
                          height: 200,
                          child: ListView.builder(
                            itemCount: _foundRows.length,
                            itemBuilder: (context, index) {
                              final item = _foundRows[index];
                              return Card(
                                margin: EdgeInsets.symmetric(vertical: 4),
                                elevation: 1,
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    _getItemDisplayText(item, _selectedColumns.take(2).toList()),
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: _getItemDisplayText(item, _selectedColumns.skip(2).take(2).toList()).isNotEmpty
                                      ? Text(
                                          _getItemDisplayText(item, _selectedColumns.skip(2).take(2).toList()),
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  trailing: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
                                  onTap: () => _showEditDialog(item, context),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
                            ),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => _showMultipleItemsDialog(context),
                            icon: Icon(Icons.list, color: Colors.white),
                            label: Text('Open All in Dialog', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Show message when exactly one item is found (dialog will auto-open)
              if (_foundRows.length == 1)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, size: 48, color: Colors.green),
                        SizedBox(height: 12),
                        Text(
                          '1 item found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Edit dialog opened automatically',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Empty states
              if (_foundRows.isEmpty && _searchController.text.isNotEmpty)
                Container(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                        SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try a different search term',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_foundRows.isEmpty && _searchController.text.isEmpty)
                Container(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                        SizedBox(height: 16),
                        Text(
                          'Manage Your Inventory',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Search for items to edit or add new items',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}