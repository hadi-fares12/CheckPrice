import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'models.dart';
import 'data_provider.dart';

class ImportExcelPage extends StatefulWidget {
  @override
  _ImportExcelPageState createState() => _ImportExcelPageState();
}

class _ImportExcelPageState extends State<ImportExcelPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _checkInitialization();
  }

  Future<void> _checkInitialization() async {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    // Wait for initialization
    while (!dataProvider.isInitialized) {
      await Future.delayed(Duration(milliseconds: 100));
    }
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Import Excel'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isInitializing 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing storage...'),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Excel File',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Dataset Name',
                            hintText: 'Enter a name for this dataset',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.label),
                          ),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _pickAndImportFile,
                          icon: _isLoading 
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.file_upload),
                          label: Text(_isLoading ? 'Importing...' : 'Select Excel File'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Consumer<DataProvider>(
                  builder: (context, dataProvider, child) {
                    final datasets = dataProvider.allDatasets;
                    if (datasets.isEmpty) {
                      return Card(
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No datasets imported yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Import your first Excel file to get started',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Imported Datasets',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        ...datasets.map((dataset) => Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(Icons.table_chart, color: Colors.blue),
                            title: Text(
                              dataset.name,
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '${dataset.rows.length} rows, ${dataset.columns.length} columns',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (dataProvider.selectedName == dataset.name)
                                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteDataset(dataset.name),
                                ),
                              ],
                            ),
                            onTap: () => dataProvider.selectDataset(dataset.name),
                          ),
                        )).toList(),
                      ],
                    );
                  },
                ),
                SizedBox(height: 20), // Add bottom padding for scroll
              ],
            ),
          ),
    );
  }

  Future<void> _pickAndImportFile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a dataset name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      const typeGroup = XTypeGroup(
        label: 'Excel files',
        extensions: ['xlsx', 'xls'],
      );
      
      final XFile? file = await openFile(
        acceptedTypeGroups: [typeGroup],
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        await _importExcelBytes(bytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importExcelBytes(List<int> bytes) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      
      List<String> columns = [];
      List<Map<String, dynamic>> rows = [];

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        
        // Get actual row and column counts from the sheet
        int maxRow = sheet.maxRows;
        int maxCol = sheet.maxCols;
        
        print('Processing sheet: $table, Rows: $maxRow, Columns: $maxCol');
        
        // Extract columns from first row
        if (maxRow > 0) {
          for (int col = 0; col < maxCol; col++) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
            String columnName = cell?.value?.toString()?.trim() ?? 'Column ${col + 1}';
            
            // Handle duplicate column names
            String finalColumnName = columnName;
            int counter = 1;
            while (columns.contains(finalColumnName)) {
              finalColumnName = '$columnName (${counter++})';
            }
            
            columns.add(finalColumnName);
          }
        }

        // Extract rows (skip header row if it exists)
        int startRow = maxRow > 0 ? 1 : 0; // Start from row 1 if we have headers, otherwise from 0
        
        for (int row = startRow; row < maxRow; row++) {
          Map<String, dynamic> rowData = {};
          bool hasData = false;
          
          for (int col = 0; col < maxCol; col++) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
            String columnName = col < columns.length ? columns[col] : 'Column ${col + 1}';
            dynamic value = cell?.value;
            
            // Convert value to appropriate type
            if (value != null) {
              if (value is String) {
                value = value.trim();
                if (value.isNotEmpty) hasData = true;
              } else {
                hasData = true;
              }
            }
            
            rowData[columnName] = value?.toString() ?? '';
          }
          
          // Only add row if it has some data
          if (hasData) {
            rows.add(rowData);
          }
        }
        
        break; // Only process first sheet
      }

      // Ensure we have at least one column
      if (columns.isEmpty) {
        columns = ['Data'];
      }

      // Ensure we have at least one row if the file was empty
      if (rows.isEmpty) {
        Map<String, dynamic> emptyRow = {};
        for (String col in columns) {
          emptyRow[col] = '';
        }
        rows.add(emptyRow);
      }

      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      await dataProvider.importExcelData(_nameController.text.trim(), columns, rows);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel file imported successfully! ${rows.length} rows, ${columns.length} columns'),
          backgroundColor: Colors.green,
        ),
      );

      _nameController.clear();
    } catch (e) {
      throw Exception('Failed to import Excel file: ${e.toString()}');
    }
  }

  Future<void> _deleteDataset(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Dataset'),
        content: Text('Are you sure you want to delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dataProvider = Provider.of<DataProvider>(context, listen: false);
        await dataProvider.deleteDataset(name);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dataset "$name" deleted successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting dataset: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}