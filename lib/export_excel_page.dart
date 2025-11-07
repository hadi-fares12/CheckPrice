import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'data_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class ExportExcelPage extends StatefulWidget {
  @override
  State<ExportExcelPage> createState() => _ExportExcelPageState();
}

class _ExportExcelPageState extends State<ExportExcelPage> {
  bool _loading = false;
  String? _message;
  List<String> selectedColumns = [];
  List<Map<String, dynamic>> selectedRows = [];
  bool selectAllColumns = true;
  bool selectAllRows = true;
  bool exportOnlyChangedRows = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSelections();
    });
  }

  void _initializeSelections() {
    final provider = Provider.of<DataProvider>(context, listen: false);
    setState(() {
      selectedColumns = List.from(provider.columns);
      if (provider.isCurrentDatasetCopy && exportOnlyChangedRows) {
        selectedRows = List.from(provider.changedRows);
        selectAllRows = true;
      } else {
        selectedRows = List.from(provider.rows);
        selectAllRows = true;
      }
    });
  }

  Future<void> _requestPermissions() async {
    if (io.Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();
      
      if (statuses[Permission.storage] != PermissionStatus.granted &&
          statuses[Permission.manageExternalStorage] != PermissionStatus.granted) {
        throw Exception('Storage permissions are required to export files');
      }
    }
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    if (selectedColumns.isEmpty || selectedRows.isEmpty) {
      setState(() { _message = 'Please select data to share first.'; });
      return;
    }

    try {
      setState(() { _loading = true; _message = null; });
      
      var excel = Excel.createExcel();
      String? defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.delete(defaultSheet);
      }
      String sheetName = 'Sheet1';
      Sheet sheet = excel[sheetName];
      
      sheet.appendRow(selectedColumns);
      
      for (var row in selectedRows) {
        sheet.appendRow(selectedColumns.map((col) => row[col]?.toString() ?? '').toList());
      }
      
      final tempDir = await getTemporaryDirectory();
      String fileName = '${provider.selectedName ?? 'shared_data'}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final tempFile = io.File(path.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(excel.encode()!);
      
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Excel data from ${provider.selectedName ?? 'my app'}',
        subject: 'Excel Data Export',
      );
      
      setState(() { _message = 'Shared successfully via WhatsApp!'; });
      
      Future.delayed(Duration(seconds: 5), () {
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      });
      
    } catch (e) {
      setState(() { _message = 'Share failed: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _downloadToPhone(BuildContext context) async {
    if (selectedColumns.isEmpty) {
      setState(() { _message = 'Please select at least one column to export.'; });
      return;
    }

    if (selectedRows.isEmpty) {
      setState(() { _message = 'Please select at least one row to export.'; });
      return;
    }

    setState(() { _loading = true; _message = null; });
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    try {
      await _requestPermissions();
      
      var excel = Excel.createExcel();
      String? defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.delete(defaultSheet);
      }
      String sheetName = 'Sheet1';
      Sheet sheet = excel[sheetName];
      
      sheet.appendRow(selectedColumns);
      
      for (var row in selectedRows) {
        sheet.appendRow(selectedColumns.map((col) => row[col]?.toString() ?? '').toList());
      }
      
      String fileName = provider.selectedName ?? 'exported_data';
      if (provider.isCurrentDatasetCopy && exportOnlyChangedRows) {
        fileName += '_changes_only';
      }
      
      if (kIsWeb) {
        setState(() { _message = 'Excel data prepared. For web, please use browser download functionality.'; });
      } else {
        String? filePath;
        if (io.Platform.isAndroid) {
          List<String> possiblePaths = [
            '/storage/emulated/0/Download',
            '/storage/emulated/0/Documents',
            '/storage/emulated/0/DCIM',
          ];
          
          io.Directory? targetDir;
          for (String path in possiblePaths) {
            final dir = io.Directory(path);
            if (await dir.exists()) {
              targetDir = dir;
              break;
            }
          }
          
          if (targetDir == null) {
            final dir = await getApplicationDocumentsDirectory();
            targetDir = dir;
          }
          
          filePath = path.join(targetDir.path, '$fileName.xlsx');
        } else {
          final dir = await getApplicationDocumentsDirectory();
          filePath = path.join(dir.path, '$fileName.xlsx');
        }
        
        final file = io.File(filePath);
        await file.writeAsBytes(excel.encode()!);
        setState(() {
          _message = 'Downloaded successfully to Downloads folder!';
        });
      }
    } catch (e) {
      setState(() { _message = 'Download failed: $e'; });
    }
    setState(() { _loading = false; });
  }

  void _toggleAllColumns() {
    final provider = Provider.of<DataProvider>(context, listen: false);
    setState(() {
      selectAllColumns = !selectAllColumns;
      if (selectAllColumns) {
        selectedColumns = List.from(provider.columns);
      } else {
        selectedColumns.clear();
      }
    });
  }

  void _toggleAllRows() {
    final provider = Provider.of<DataProvider>(context, listen: false);
    setState(() {
      selectAllRows = !selectAllRows;
      if (selectAllRows) {
        if (provider.isCurrentDatasetCopy && exportOnlyChangedRows) {
          selectedRows = List.from(provider.changedRows);
        } else {
          selectedRows = List.from(provider.rows);
        }
      } else {
        selectedRows.clear();
      }
    });
  }

  void _toggleExportOnlyChangedRows() {
    final provider = Provider.of<DataProvider>(context, listen: false);
    setState(() {
      exportOnlyChangedRows = !exportOnlyChangedRows;
      if (exportOnlyChangedRows && provider.isCurrentDatasetCopy) {
        selectedRows = List.from(provider.changedRows);
        selectAllRows = true;
      } else {
        selectedRows = List.from(provider.rows);
        selectAllRows = true;
      }
    });
  }

  void _toggleColumn(String column) {
    setState(() {
      if (selectedColumns.contains(column)) {
        selectedColumns.remove(column);
      } else {
        selectedColumns.add(column);
      }
      selectAllColumns = selectedColumns.length == Provider.of<DataProvider>(context, listen: false).columns.length;
    });
  }

  void _toggleRow(int index) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    List<Map<String, dynamic>> sourceRows;
    
    if (provider.isCurrentDatasetCopy && exportOnlyChangedRows) {
      sourceRows = provider.changedRows;
    } else {
      sourceRows = provider.rows;
    }
    
    if (index < sourceRows.length) {
      final row = sourceRows[index];
      setState(() {
        if (selectedRows.contains(row)) {
          selectedRows.remove(row);
        } else {
          selectedRows.add(row);
        }
        selectAllRows = selectedRows.length == sourceRows.length;
      });
    }
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Export Excel'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          if (provider.datasetNames.isEmpty) {
            return Container(
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
              child: Center(
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
                    Text('Please import Excel data first'),
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

          if (provider.columns.isEmpty) {
            return Container(
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning, size: 64, color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      'No data available to export',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Please import Excel data first'),
                  ],
                ),
              ),
            );
          }

          return Container(
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
                          Row(
                            children: [
                              Icon(Icons.folder, color: Theme.of(context).colorScheme.primary),
                              SizedBox(width: 8),
                              Text(
                                'Select Dataset to Export',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
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
                                _initializeSelections();
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
                  
                  // Change Tracking Info
                  if (provider.isCurrentDatasetCopy) ...[
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
                                Icon(Icons.track_changes, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  'Change Tracking',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'This is a copy of "${provider.originalDatasetName ?? 'Unknown'}"',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard('Total', provider.changeStats['total'] ?? 0, Colors.blue),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatCard('Original', provider.changeStats['original'] ?? 0, Colors.grey),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatCard('Updated', provider.changeStats['updated'] ?? 0, Colors.orange),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatCard('New', provider.changeStats['new'] ?? 0, Colors.green),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Checkbox(
                                  value: exportOnlyChangedRows,
                                  onChanged: (value) => _toggleExportOnlyChangedRows(),
                                ),
                                Expanded(
                                  child: Text(
                                    'Export only changed rows (${provider.changeStats['changed'] ?? 0} rows)',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Column Selection
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
                              Icon(Icons.view_column, color: Theme.of(context).colorScheme.secondary),
                              SizedBox(width: 8),
                              Text(
                                'Select Columns to Export',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Spacer(),
                              Checkbox(
                                value: selectAllColumns,
                                onChanged: (value) => _toggleAllColumns(),
                              ),
                              Text('All'),
                            ],
                          ),
                          SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: provider.columns.map((column) {
                              return FilterChip(
                                label: Text(column),
                                selected: selectedColumns.contains(column),
                                onSelected: (selected) => _toggleColumn(column),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Row Selection
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
                              Icon(Icons.table_rows, color: Theme.of(context).colorScheme.secondary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  provider.isCurrentDatasetCopy && exportOnlyChangedRows
                                      ? 'Select Changed Rows (${selectedRows.length}/${provider.changedRows.length})'
                                      : 'Select Rows (${selectedRows.length}/${provider.rows.length})',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Checkbox(
                                value: selectAllRows,
                                onChanged: (value) => _toggleAllRows(),
                              ),
                              Text('All'),
                            ],
                          ),
                          SizedBox(height: 16),
                          Container(
                            height: 200,
                            child: ListView.builder(
                              itemCount: provider.isCurrentDatasetCopy && exportOnlyChangedRows
                                  ? provider.changedRows.length
                                  : provider.rows.length,
                              itemBuilder: (context, index) {
                                List<Map<String, dynamic>> sourceRows;
                                if (provider.isCurrentDatasetCopy && exportOnlyChangedRows) {
                                  sourceRows = provider.changedRows;
                                } else {
                                  sourceRows = provider.rows;
                                }
                                
                                final row = sourceRows[index];
                                final isSelected = selectedRows.contains(row);
                                
                                int originalIndex = provider.rows.indexOf(row);
                                final rowStatus = provider.isCurrentDatasetCopy && originalIndex >= 0
                                    ? provider.getRowStatus(originalIndex)
                                    : 'Original';
                                
                                return ListTile(
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (value) => _toggleRow(index),
                                  ),
                                  title: Row(
                                    children: [
                                      Text('Row ${originalIndex >= 0 ? originalIndex + 1 : index + 1}'),
                                      if (provider.isCurrentDatasetCopy && originalIndex >= 0) ...[
                                        SizedBox(width: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: rowStatus == 'New' ? Colors.green : 
                                                   rowStatus == 'Updated' ? Colors.orange : Colors.grey,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            rowStatus,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    provider.columns.take(3).map((col) => '${col}: ${row[col]}').join(', '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Two Main Buttons
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [Color(0xFF25D366), Color(0xFF25D366).withOpacity(0.8)],
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.share, color: Colors.white, size: 24),
                        label: Text(
                          'Share via WhatsApp',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onPressed: _loading ? null : () => _shareViaWhatsApp(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.blue.withOpacity(0.8)],
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.download, color: Colors.white, size: 24),
                        label: Text(
                          'Download to Phone',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onPressed: _loading ? null : () => _downloadToPhone(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  if (_loading) CircularProgressIndicator(),
                  if (_message != null) 
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _message!.contains('successfully') || _message!.contains('Downloaded') 
                            ? Colors.green.withOpacity(0.1) 
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _message!.contains('successfully') || _message!.contains('Downloaded') 
                              ? Colors.green 
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}