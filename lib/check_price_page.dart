import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CheckPricePage extends StatefulWidget {
  @override
  State<CheckPricePage> createState() => _CheckPricePageState();
}

class _CheckPricePageState extends State<CheckPricePage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _foundRows = [];
  Set<String> _selectedColumns = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<DataProvider>(context, listen: false);
    if (_selectedColumns.isEmpty && provider.columns.isNotEmpty) {
      setState(() {
        _selectedColumns = Set<String>.from(provider.columns);
      });
    } else if (provider.columns.isNotEmpty) {
      // Update selected columns if dataset changed - keep columns that exist in new dataset
      setState(() {
        _selectedColumns = _selectedColumns.intersection(Set<String>.from(provider.columns));
        // If no columns left, add all columns
        if (_selectedColumns.isEmpty) {
          _selectedColumns = Set<String>.from(provider.columns);
        }
      });
    }
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
        _showItemDialog(results.first, context);
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

  void _showItemDialog(Map<String, dynamic> item, BuildContext context) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 8),
            Text('Item Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Display selected columns only
              ..._selectedColumns.map((col) {
                final value = item[col]?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        child: Text(
                          '$col:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          value.isEmpty ? 'N/A' : value,
                          style: TextStyle(fontSize: 14),
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
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
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

  String _getItemDisplayText(Map<String, dynamic> item, List<String> columns) {
    // Get values from selected columns
    List<String> values = [];
    for (var col in columns) {
      final value = item[col]?.toString() ?? '';
      if (value.isNotEmpty) {
        values.add(value);
      }
    }
    return values.isEmpty ? 'No data' : values.join(' - ');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    
    if (provider.datasetNames.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Check Price'),
          backgroundColor: Theme.of(context).colorScheme.primary,
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
        title: Text('Check Price'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Dataset Selection
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Select Dataset to Search', Icons.folder, Theme.of(context).colorScheme.primary),
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
                          '${provider.rows.length} rows, ${provider.columns.length} columns',
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
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Select Columns to Display', Icons.view_column, Theme.of(context).colorScheme.secondary),
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
                elevation: 4,
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
                                hintText: 'Enter search term...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                                ),
                                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
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
                                colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.8)],
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () => _search(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: EdgeInsets.all(12),
                              ),
                              child: Icon(Icons.search, color: Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.secondary.withOpacity(0.8)],
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () => _scanBarcode(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: EdgeInsets.all(12),
                              ),
                              child: Icon(Icons.qr_code_scanner, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              
              // Results as List (for better tap interaction)
              if (_foundRows.isNotEmpty && _foundRows.length > 1) // Only show list if multiple results
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Search Results (${_foundRows.length} found)', Icons.search, Colors.green),
                        SizedBox(height: 12),
                        Container(
                          height: 300,
                          child: ListView.builder(
                            itemCount: _foundRows.length,
                            itemBuilder: (context, index) {
                              final item = _foundRows[index];
                              // Get non-empty values for title
                              List<String> titleValues = [];
                              for (var col in _selectedColumns.take(2)) {
                                final value = item[col]?.toString() ?? '';
                                if (value.isNotEmpty) {
                                  titleValues.add(value);
                                }
                              }
                              
                              // Get non-empty values for subtitle
                              List<String> subtitleValues = [];
                              for (var col in _selectedColumns.skip(2).take(2)) {
                                final value = item[col]?.toString() ?? '';
                                if (value.isNotEmpty) {
                                  subtitleValues.add(value);
                                }
                              }
                              
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
                                    titleValues.isEmpty ? 'Item ${index + 1}' : titleValues.join(' - '),
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: subtitleValues.isNotEmpty 
                                      ? Text(
                                          subtitleValues.join(', '),
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                                  onTap: () => _showItemDialog(item, context),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Show message when exactly one item is found (dialog will auto-open)
              if (_foundRows.length == 1)
                Card(
                  elevation: 4,
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
                          'Item details opened automatically',
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
                        Icon(Icons.search, size: 64, color: Colors.grey.shade400),
                        SizedBox(height: 16),
                        Text(
                          'Ready to search',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Enter a search term or scan a barcode',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}