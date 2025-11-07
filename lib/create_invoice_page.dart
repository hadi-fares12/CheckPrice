import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'data_provider.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as path;

class CreateInvoicePage extends StatefulWidget {
  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final _searchController = TextEditingController();
  final _invoiceNameController = TextEditingController();
  List<Map<String, dynamic>> _foundRows = [];
  Map<String, dynamic>? _selectedItem;
  final _quantityController = TextEditingController(text: '1');
  List<Map<String, dynamic>> _invoiceItems = [];
  bool _invoiceCreated = false;
  bool _multiSelectMode = false;
  Set<int> _selectedIndices = Set<int>();

  // Column selection for export
  Set<String> _selectedExportColumns = {};
  List<String> _availableColumns = [];

  @override
  void initState() {
    super.initState();
    _invoiceNameController.text = 'Invoice_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeAvailableColumns();
  }

  void _initializeAvailableColumns() {
    final provider = Provider.of<DataProvider>(context, listen: false);
    if (provider.columns.isNotEmpty) {
      setState(() {
        _availableColumns = List.from(provider.columns);
        // Select ALL columns by default
        _selectedExportColumns = Set.from(_availableColumns);
        // Always include quantity
        _selectedExportColumns.add('qty');
      });
    }
  }

  void _showExportColumnSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.view_column, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text('Select Columns for Export'),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Choose which columns to include in exported invoice:',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _selectedExportColumns = Set.from(_availableColumns)..add('qty');
                          });
                        },
                        child: Text('Select All'),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _selectedExportColumns.clear();
                          });
                        },
                        child: Text('Clear All'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _availableColumns.length + 1,
                      itemBuilder: (context, index) {
                        final column = index < _availableColumns.length 
                            ? _availableColumns[index] 
                            : 'qty';
                        final isQty = column == 'qty';
                        
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 2),
                          child: CheckboxListTile(
                            title: Text(
                              isQty ? 'QUANTITY (QTY)' : column,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isQty ? FontWeight.bold : FontWeight.normal,
                                color: isQty ? Colors.green : Colors.black,
                              ),
                            ),
                            value: _selectedExportColumns.contains(column),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedExportColumns.add(column);
                                } else {
                                  _selectedExportColumns.remove(column);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Selected: ${_selectedExportColumns.length} columns',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {});
                },
                child: Text('Save Selection'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _invoiceNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _search(BuildContext context) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final results = provider.search(query);
    setState(() { 
      _foundRows = results;
      _selectedItem = null;
      _selectedIndices.clear();
    });

    if (results.length == 1) {
      _showItemDetailsDialog(context, results.first);
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

  void _showItemDetailsDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Item Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show all available data from the item
              ...item.entries.map((entry) {
                if (entry.value != null && entry.value.toString().isNotEmpty) {
                  return _buildDetailRow(entry.key, entry.value.toString());
                }
                return SizedBox();
              }).toList(),
              SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              _addSingleItemToInvoice(item);
              Navigator.of(context).pop();
            },
            child: Text('Add to Invoice'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _toggleItemSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _addSelectedItemsToInvoice() {
    if (_selectedIndices.isEmpty) return;

    for (int index in _selectedIndices) {
      final item = _foundRows[index];
      final quantity = 1;
      _addItemToInvoiceList(item, quantity);
    }

    setState(() {
      _selectedIndices.clear();
      _foundRows.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_selectedIndices.length} items added to invoice')),
    );
  }

  void _addSingleItemToInvoice(Map<String, dynamic> item) {
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    _addItemToInvoiceList(item, quantity);
    setState(() {
      _selectedItem = null;
      _quantityController.text = '1';
    });
  }

  void _addItemToInvoiceList(Map<String, dynamic> item, int quantity) {
    if (quantity <= 0) return;

    // Create a copy of the original item with ALL data + quantity
    final invoiceItem = Map<String, dynamic>.from(item);
    invoiceItem['qty'] = quantity;

    // Check if item already exists in invoice by comparing key fields
    final existingIndex = _invoiceItems.indexWhere((existingItem) {
      return _getItemKey(existingItem) == _getItemKey(item);
    });

    if (existingIndex != -1) {
      setState(() {
        _invoiceItems[existingIndex]['qty'] += quantity;
      });
    } else {
      setState(() {
        _invoiceItems.add(invoiceItem);
      });
    }
  }

  String _getItemKey(Map<String, dynamic> item) {
    // Create a unique key based on important fields
    final code = item['Item Code'] ?? item['item_code'] ?? item['ITEM_CODE'] ?? '';
    final name = item['Item Name'] ?? item['item_name'] ?? item['ITEM_NAME'] ?? '';
    final barcode = item['Barcode'] ?? item['barcode'] ?? item['BARCODE'] ?? '';
    
    return '$code$name$barcode';
  }

  void _removeInvoiceItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
    });
  }

  void _createInvoice() {
    if (_invoiceNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter invoice name'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _invoiceCreated = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice created! You can now add items.'), backgroundColor: Colors.green),
    );
  }

  Future<void> _exportInvoice() async {
    if (_invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No items in invoice'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedExportColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one column for export'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];
      
      // Use selected columns for headers
      List<String> headers = _selectedExportColumns.toList();
      sheet.appendRow(headers);
      
      // Write invoice items with selected columns only
      for (var item in _invoiceItems) {
        List<String> row = [];
        for (var col in _selectedExportColumns) {
          if (col == 'qty') {
            row.add(item['qty']?.toString() ?? '1');
          } else {
            row.add(item[col]?.toString() ?? '');
          }
        }
        sheet.appendRow(row);
      }
      
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      String fileName = '${_invoiceNameController.text.trim()}.xlsx';
      final tempFile = io.File(path.join(tempDir.path, fileName));
      
      var fileBytes = excel.save();
      if (fileBytes != null) {
        await tempFile.writeAsBytes(fileBytes);
        
        await Share.shareXFiles(
          [XFile(tempFile.path)],
          text: 'Invoice: ${_invoiceNameController.text.trim()}',
          subject: 'Invoice',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice shared successfully!'), backgroundColor: Colors.green),
        );
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing invoice: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _clearInvoice() {
    setState(() {
      _invoiceItems.clear();
      _invoiceCreated = false;
      _selectedIndices.clear();
      _multiSelectMode = false;
      _invoiceNameController.text = 'Invoice_${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    
    if (provider.datasetNames.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Create Invoice')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text('No Excel datasets available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Please import an Excel file first'),
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
        title: Text('Create Invoice'),
        backgroundColor: Color(0xFF9C27B0),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF9C27B0).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Invoice Creation Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt, color: Color(0xFF9C27B0)),
                          SizedBox(width: 8),
                          Text('Invoice Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _invoiceNameController,
                        decoration: InputDecoration(
                          labelText: 'Invoice Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.label),
                        ),
                        enabled: !_invoiceCreated,
                      ),
                      SizedBox(height: 16),
                      if (!_invoiceCreated)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.create),
                            label: Text('Create Invoice'),
                            onPressed: _createInvoice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF9C27B0),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              if (_invoiceCreated) ...[
                // Dataset Selection
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.folder, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Select Dataset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: provider.selectedName,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: provider.datasetNames.map((name) {
                            return DropdownMenuItem(value: name, child: Text(name));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              provider.selectDataset(value);
                              setState(() {
                                _foundRows.clear();
                                _selectedItem = null;
                                _selectedIndices.clear();
                                _initializeAvailableColumns();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Search Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  labelText: 'Search item',
                                  hintText: 'Enter search term or scan barcode...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onSubmitted: (_) => _search(context),
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(colors: [Colors.blue, Colors.blue.withOpacity(0.8)]),
                              ),
                              child: ElevatedButton(
                                onPressed: () => _search(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Icon(Icons.search, color: Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(colors: [Colors.green, Colors.green.withOpacity(0.8)]),
                              ),
                              child: ElevatedButton(
                                onPressed: () => _scanBarcode(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Icon(Icons.qr_code_scanner, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(
                              value: _multiSelectMode,
                              onChanged: (value) {
                                setState(() {
                                  _multiSelectMode = value ?? false;
                                  _selectedIndices.clear();
                                });
                              },
                            ),
                            Text('Multi-select mode'),
                            SizedBox(width: 16),
                            if (_multiSelectMode && _selectedIndices.isNotEmpty)
                              ElevatedButton.icon(
                                icon: Icon(Icons.add),
                                label: Text('Add ${_selectedIndices.length} items'),
                                onPressed: _addSelectedItemsToInvoice,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Search Results
                if (_foundRows.isNotEmpty)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Search Results (${_foundRows.length} found)', 
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              if (_foundRows.length == 1) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '1 item found - details opened automatically',
                                    style: TextStyle(color: Colors.green, fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 12),
                          Container(
                            height: _foundRows.length > 3 ? 300 : null,
                            constraints: _foundRows.length > 3 ? BoxConstraints(maxHeight: 300) : null,
                            child: ListView.builder(
                              shrinkWrap: _foundRows.length <= 3,
                              physics: _foundRows.length > 3 ? AlwaysScrollableScrollPhysics() : NeverScrollableScrollPhysics(),
                              itemCount: _foundRows.length,
                              itemBuilder: (context, index) {
                                final item = _foundRows[index];
                                
                                return Card(
                                  margin: EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: _multiSelectMode 
                                        ? Checkbox(
                                            value: _selectedIndices.contains(index),
                                            onChanged: (value) => _toggleItemSelection(index),
                                          )
                                        : Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text('${index + 1}'),
                                          ),
                                    title: Text(
                                      _getItemDisplayText(item),
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      _getItemSubtitle(item),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: _multiSelectMode 
                                        ? null 
                                        : Icon(Icons.chevron_right, color: Colors.blue),
                                    onTap: _multiSelectMode 
                                        ? () => _toggleItemSelection(index)
                                        : () => _showItemDetailsDialog(context, item),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Invoice Items
                if (_invoiceItems.isNotEmpty)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Invoice Items (${_invoiceItems.length})', 
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Spacer(),
                              Icon(Icons.shopping_cart, color: Colors.green),
                            ],
                          ),
                          SizedBox(height: 12),
                          ..._invoiceItems.asMap().entries.map((entry) {
                            int index = entry.key;
                            final item = entry.value;
                            
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.withOpacity(0.1),
                                  child: Text('${item['qty']}', 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                ),
                                title: Text(_getItemDisplayText(item)),
                                subtitle: Text('Quantity: ${item['qty']}'),
                                trailing: IconButton(
                                  icon: Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => _removeInvoiceItem(index),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                // Action Buttons
                if (_invoiceCreated)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Column Selector Button
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(colors: [Colors.purple, Colors.purple.withOpacity(0.8)]),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.view_column, color: Colors.white),
                                label: Text(
                                  'Select Export Columns (${_selectedExportColumns.length})',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _showExportColumnSelector(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.share),
                                  label: Text('Share via WhatsApp'),
                                  onPressed: _invoiceItems.isNotEmpty ? _exportInvoice : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.clear),
                                  label: Text('Clear Invoice'),
                                  onPressed: _clearInvoice,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _getItemDisplayText(Map<String, dynamic> item) {
    final code = item['Item Code'] ?? item['item_code'] ?? item['ITEM_CODE'] ?? '';
    final name = item['Item Name'] ?? item['item_name'] ?? item['ITEM_NAME'] ?? '';
    
    if (code.isNotEmpty && name.isNotEmpty) {
      return '$code - $name';
    } else if (code.isNotEmpty) {
      return code.toString();
    } else if (name.isNotEmpty) {
      return name.toString();
    } else {
      final values = item.values.where((v) => v != null && v.toString().isNotEmpty).take(2).toList();
      return values.isNotEmpty ? values.join(' - ') : 'Item';
    }
  }

  String _getItemSubtitle(Map<String, dynamic> item) {
    final barcode = item['Barcode'] ?? item['barcode'] ?? '';
    final price = item['Price'] ?? item['price'] ?? '';
    
    List<String> info = [];
    if (barcode.isNotEmpty) info.add('Barcode: $barcode');
    if (price.isNotEmpty) info.add('Price: $price');
    
    return info.isNotEmpty ? info.join(' | ') : 'Tap for details';
  }
}