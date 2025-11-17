import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'data_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImportExcelPage extends StatefulWidget {
  @override
  _ImportExcelPageState createState() => _ImportExcelPageState();
}

class _ImportExcelPageState extends State<ImportExcelPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pathController = TextEditingController();
  bool _isLoading = false;
  bool _isInitializing = true;
  Timer? _autoRefreshTimer;
  bool _autoRefreshEnabled = false;
  int _autoRefreshInterval = 5; // minutes
  String _globalImportUrl = '';
  XFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    _checkInitialization();
    _loadSettings();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _globalImportUrl = prefs.getString('global_import_url') ?? '';
      _autoRefreshEnabled = prefs.getBool('auto_refresh_enabled') ?? false;
      _autoRefreshInterval = prefs.getInt('auto_refresh_interval') ?? 5;
    });
    
    if (_autoRefreshEnabled && _globalImportUrl.isNotEmpty) {
      _startAutoRefreshTimer();
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_import_url', _globalImportUrl);
    await prefs.setBool('auto_refresh_enabled', _autoRefreshEnabled);
    await prefs.setInt('auto_refresh_interval', _autoRefreshInterval);
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      Duration(minutes: _autoRefreshInterval),
      (timer) {
        if (_autoRefreshEnabled && _globalImportUrl.isNotEmpty) {
          _refreshFromGlobalUrl();
        }
      },
    );
  }

  Future<void> _checkInitialization() async {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    
    // Wait for data provider to initialize
    int attempts = 0;
    while (!dataProvider.isInitialized && attempts < 50) {
      await Future.delayed(Duration(milliseconds: 100));
      attempts++;
    }
    
    setState(() {
      _isInitializing = false;
    });
  }

  Future<void> _showSettingsDialog() async {
    final urlController = TextEditingController(text: _globalImportUrl);
    final intervalController = TextEditingController(text: _autoRefreshInterval.toString());
    bool autoRefreshEnabled = _autoRefreshEnabled;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.settings, color: Colors.blue),
                SizedBox(width: 8),
                Text('Import Settings'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Global Import URL or File Path',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: urlController,
                          decoration: InputDecoration(
                            hintText: 'Enter URL or select local file',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                          ),
                          maxLines: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.folder_open),
                        onPressed: () async {
                          const typeGroup = XTypeGroup(
                            label: 'Excel files',
                            extensions: ['xlsx', 'xls'],
                          );
                          
                          final XFile? file = await openFile(
                            acceptedTypeGroups: [typeGroup],
                          );

                          if (file != null) {
                            urlController.text = file.path;
                            setState(() {});
                          }
                        },
                        tooltip: 'Select Local File',
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: autoRefreshEnabled,
                        onChanged: (value) {
                          setState(() {
                            autoRefreshEnabled = value ?? false;
                          });
                        },
                      ),
                      Text('Enable Auto-Refresh'),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Auto-Refresh Interval (minutes)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: intervalController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '5',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 8),
                  _buildUrlInfo(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final interval = int.tryParse(intervalController.text) ?? 5;
                  if (interval < 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Interval must be at least 1 minute')),
                    );
                    return;
                  }

                  setState(() {
                    _globalImportUrl = urlController.text.trim();
                    _autoRefreshEnabled = autoRefreshEnabled;
                    _autoRefreshInterval = interval;
                  });

                  await _saveSettings();

                  if (_autoRefreshEnabled && _globalImportUrl.isNotEmpty) {
                    _startAutoRefreshTimer();
                  } else {
                    _autoRefreshTimer?.cancel();
                  }

                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Settings saved successfully!')),
                  );
                },
                child: Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUrlInfo() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supported Sources:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
          ),
          SizedBox(height: 8),
          _buildInfoItem('Web URL', 'https://example.com/file.xlsx'),
          _buildInfoItem('Local File', '/path/to/file.xlsx'),
          _buildInfoItem('Google Drive', 'Use "Share" → "Copy link"'),
          _buildInfoItem('Dropbox', 'Use "Share" → "Copy link"'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String type, String example) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                children: [
                  TextSpan(text: '$type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: example),
                ],
              ),
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
        title: Text('Import Excel'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Import Settings',
          ),
          if (_globalImportUrl.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _refreshFromGlobalUrl,
              tooltip: 'Refresh from URL',
            ),
          if (_autoRefreshEnabled && _globalImportUrl.isNotEmpty)
            Tooltip(
              message: 'Auto-refresh enabled (every $_autoRefreshInterval minutes)',
              child: Icon(Icons.autorenew, color: Colors.green),
            ),
        ],
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
                if (_globalImportUrl.isNotEmpty)
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.link, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Global Import Source',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                              Spacer(),
                              if (_autoRefreshEnabled)
                                Row(
                                  children: [
                                    Icon(Icons.autorenew, color: Colors.green, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Auto (${_autoRefreshInterval}m)',
                                      style: TextStyle(color: Colors.green, fontSize: 12),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            _globalImportUrl,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _importFromGlobalUrl,
                                  icon: _isLoading 
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Icon(Icons.download),
                                  label: Text(_isLoading ? 'Importing...' : 'Import from Source'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                onPressed: _refreshFromGlobalUrl,
                                icon: Icon(Icons.refresh),
                                tooltip: 'Refresh Source',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_globalImportUrl.isNotEmpty) SizedBox(height: 16),

                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Local Excel File',
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
                        SizedBox(height: 12),
                        TextField(
                          controller: _pathController,
                          decoration: InputDecoration(
                            labelText: 'File Path',
                            hintText: 'Select an Excel file to import',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.folder),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.folder_open),
                              onPressed: _selectFile,
                            ),
                          ),
                          readOnly: true,
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (_selectedFile == null || _isLoading) ? null : _importSelectedFile,
                                icon: _isLoading 
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(Icons.file_upload),
                                label: Text(_isLoading ? 'Importing...' : 'Import Selected File'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _selectFile,
                              icon: Icon(Icons.search),
                              label: Text('Select File'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedFile != null) ...[
                          SizedBox(height: 8),
                          Text(
                            'Selected: ${_selectedFile!.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${dataset.rows.length} rows, ${dataset.columns.length} columns',
                                  style: TextStyle(fontSize: 12),
                                ),
                                if (dataset.importPath != null && dataset.importPath!.isNotEmpty)
                                  Text(
                                    'Path: ${dataset.importPath}',
                                    style: TextStyle(fontSize: 10, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
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
                SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Future<void> _selectFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Excel files',
        extensions: ['xlsx', 'xls'],
      );
      
      final XFile? file = await openFile(
        acceptedTypeGroups: [typeGroup],
      );

      if (file != null) {
        setState(() {
          _selectedFile = file;
          _pathController.text = file.path;
        });

        // Auto-generate dataset name from filename if empty
        if (_nameController.text.trim().isEmpty) {
          String fileName = file.name;
          // Remove file extension
          if (fileName.toLowerCase().endsWith('.xlsx') || fileName.toLowerCase().endsWith('.xls')) {
            fileName = fileName.substring(0, fileName.lastIndexOf('.'));
          }
          _nameController.text = fileName;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importSelectedFile() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a file first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
      final bytes = await _selectedFile!.readAsBytes();
      await _importExcelBytes(bytes, _selectedFile!.path);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel file imported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
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

  Future<void> _importFromGlobalUrl() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a dataset name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_globalImportUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please set a global import URL in settings'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<int> bytes = await _getFileBytesFromPath(_globalImportUrl);
      await _importExcelBytes(bytes, _globalImportUrl);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel file imported successfully from URL!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing from URL: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshFromGlobalUrl() async {
    if (_globalImportUrl.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      List<int> bytes = await _getFileBytesFromPath(_globalImportUrl);
      
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final datasets = dataProvider.allDatasets;
      
      String datasetName;
      if (datasets.isNotEmpty) {
        datasetName = datasets.first.name;
      } else {
        datasetName = 'Auto-Import';
      }
      
      _nameController.text = datasetName;
      await _importExcelBytes(bytes, _globalImportUrl);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data refreshed from URL successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing from URL: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _convertCloudStorageLink(String url) {
    try {
      if (url.contains('drive.google.com') || url.contains('docs.google.com/spreadsheets')) {
        RegExp regExp = RegExp(r'/d/([a-zA-Z0-9-_]+)');
        Match? match = regExp.firstMatch(url);
        if (match != null && match.groupCount >= 1) {
          String fileId = match.group(1)!;
          return 'https://docs.google.com/spreadsheets/d/$fileId/export?format=xlsx';
        }
      }
      
      if (url.contains('dropbox.com')) {
        if (url.contains('?dl=0')) {
          return url.replaceAll('?dl=0', '?dl=1');
        }
        if (!url.contains('?dl=')) {
          return url + (url.contains('?') ? '&dl=1' : '?dl=1');
        }
      }
      
      if (url.contains('onedrive.live.com') || url.contains('1drv.ms')) {
        if (url.contains('/redir?')) {
          return url.replaceAll('/redir?', '/download?');
        }
        if (url.contains('/edit?')) {
          return url.replaceAll('/edit?', '/download?');
        }
      }
      
      return url;
    } catch (e) {
      print('Error converting cloud link: $e');
      return url;
    }
  }

  Future<List<int>> _getFileBytesFromPath(String path) async {
    try {
      print('Attempting to load file from: $path');
      
      if (path.toLowerCase().startsWith('http')) {
        String originalPath = path;
        path = _convertCloudStorageLink(path);
        
        if (originalPath != path) {
          print('Converted cloud link to: $path');
        }
      }
      
      if (path.toLowerCase().startsWith('http')) {
        final response = await http.get(Uri.parse(path));
        
        if (response.statusCode == 200) {
          final contentLength = response.contentLength ?? 0;
          final bodyBytes = response.bodyBytes;
          
          if (contentLength < 100) {
            final content = String.fromCharCodes(bodyBytes).toLowerCase();
            if (content.contains('<html') || 
                content.contains('error') || 
                content.contains('access denied') ||
                content.contains('google drive') ||
                content.contains('dropbox') ||
                content.contains('onedrive') ||
                content.contains('sign in')) {
              throw Exception('Received error page instead of Excel file. The file may not be publicly accessible or the URL format is incorrect.');
            }
          }
          
          if (bodyBytes.length >= 4) {
            if (bodyBytes[0] != 0x50 || bodyBytes[1] != 0x4B) {
              if (bodyBytes[0] != 0xD0 || bodyBytes[1] != 0xCF) {
                throw Exception('Downloaded file is not a valid Excel file. Please check the URL and ensure the file is publicly accessible.');
              }
            }
          }
          
          return bodyBytes;
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          throw Exception('Access denied (HTTP ${response.statusCode}). Please make sure the file is publicly accessible.');
        } else if (response.statusCode == 404) {
          throw Exception('File not found (HTTP 404). Please check the URL.');
        } else {
          throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }
      }
      
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      } else {
        throw Exception('Local file not found: $path');
      }
    } catch (e) {
      throw Exception('Failed to read file from path: ${e.toString()}');
    }
  }

  Future<void> _importExcelBytes(List<int> bytes, String sourcePath) async {
    try {
      if (bytes.isEmpty) {
        throw Exception('The file is empty.');
      }
      
      // Validate Excel file signature
      bool isValidExcel = false;
      if (bytes.length >= 4) {
        // Check for ZIP signature (modern Excel files)
        if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
          isValidExcel = true;
        }
        // Check for OLE signature (older Excel files)
        else if (bytes[0] == 0xD0 && bytes[1] == 0xCF) {
          isValidExcel = true;
        }
      }
      
      if (!isValidExcel) {
        throw Exception('Invalid Excel file format. The file may be corrupted or not an Excel file.');
      }
      
      final excel = excel_lib.Excel.decodeBytes(bytes);
      
      // FIX: Check if excel.tables is not null and not empty
      if (excel.tables == null || excel.tables!.isEmpty) {
        throw Exception('No worksheets found in the Excel file.');
      }
      
      List<String> columns = [];
      List<Map<String, dynamic>> rows = [];

      // FIX: Use safe iteration over tables
      for (var tableKey in excel.tables!.keys) {
        final sheet = excel.tables![tableKey];
        
        // FIX: Add null check for sheet
        if (sheet == null) {
          print('Warning: Sheet $tableKey is null, skipping...');
          continue;
        }
        
        // FIX: Safe access to sheet properties
        int maxRow = sheet.maxRows;
        int maxCol = sheet.maxCols;
        
        print('Processing sheet: $tableKey, Rows: $maxRow, Columns: $maxCol');
        
        // Process column headers with safe indexing
        if (maxRow > 0) {
          for (int col = 0; col < maxCol; col++) {
            try {
              final cell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
              final cellValue = cell.value;
              String columnName = _formatCellValue(cellValue);
              
              if (columnName.isEmpty) {
                columnName = 'Column ${col + 1}';
              }
              
              // Ensure unique column names
              String finalColumnName = columnName;
              int counter = 1;
              while (columns.contains(finalColumnName)) {
                finalColumnName = '$columnName (${counter++})';
              }
              
              columns.add(finalColumnName);
            } catch (e) {
              print('Error processing column $col: $e');
              columns.add('Column ${col + 1}');
            }
          }
        }

        // Process data rows with safe indexing
        int startRow = maxRow > 0 ? 1 : 0;
        
        for (int row = startRow; row < maxRow; row++) {
          try {
            Map<String, dynamic> rowData = {};
            bool hasData = false;
            
            for (int col = 0; col < maxCol; col++) {
              try {
                final cell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
                final cellValue = cell.value;
                String columnName = col < columns.length ? columns[col] : 'Column ${col + 1}';
                String value = _formatCellValue(cellValue);
                
                if (value.isNotEmpty) {
                  hasData = true;
                }
                
                rowData[columnName] = value;
              } catch (e) {
                print('Error processing cell at row $row, col $col: $e');
                String columnName = col < columns.length ? columns[col] : 'Column ${col + 1}';
                rowData[columnName] = '';
              }
            }
            
            if (hasData || row == startRow) { // Include first row even if empty for structure
              rows.add(rowData);
            }
          } catch (e) {
            print('Error processing row $row: $e');
          }
        }
        
        break; // Only process the first sheet for now
      }

      // Ensure we have at least one column
      if (columns.isEmpty) {
        columns = ['Data'];
      }

      // Ensure we have at least one row
      if (rows.isEmpty) {
        Map<String, dynamic> emptyRow = {};
        for (String col in columns) {
          emptyRow[col] = '';
        }
        rows.add(emptyRow);
      }

      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      
      // Improved retry logic for storage initialization
      int retryCount = 0;
      bool success = false;
      
      while (retryCount < 3 && !success) {
        try {
          await dataProvider.importExcelData(
            _nameController.text.trim(), 
            columns, 
            rows,
            importPath: sourcePath,
          );
          success = true;
        } catch (e) {
          retryCount++;
          if (retryCount == 3) {
            throw Exception('Storage error after 3 attempts: ${e.toString()}');
          }
          await Future.delayed(Duration(milliseconds: 200 * retryCount));
        }
      }

    } catch (e) {
      throw Exception('Failed to import Excel file: ${e.toString()}');
    }
  }

  // FIXED: Corrected cell value formatting for the excel package
  String _formatCellValue(dynamic cellValue) {
    try {
      if (cellValue == null) return '';
      
      // The excel package returns basic Dart types, not custom cell value types
      // Handle different value types safely
      if (cellValue is String) {
        return cellValue.trim();
      } else if (cellValue is int) {
        return cellValue.toString();
      } else if (cellValue is double) {
        return cellValue.toString();
      } else if (cellValue is bool) {
        return cellValue.toString();
      }
      
      // Fallback to string conversion for any other types
      String stringValue = cellValue.toString();
      
      // Remove asterisk from beginning if present but preserve leading zeros
      if (stringValue.startsWith('*')) {
        stringValue = stringValue.substring(1);
      }
      
      // Trim whitespace but preserve internal spaces and leading zeros
      stringValue = stringValue.trim();
      
      // Special handling to preserve leading zeros in numbers
      if (stringValue.isNotEmpty) {
        // Check if this looks like a number with leading zeros (like 0012, 000123, etc.)
        if (RegExp(r'^0+[0-9]+$').hasMatch(stringValue)) {
          // Preserve the string as-is to maintain leading zeros
          return stringValue;
        }
      }
      
      return stringValue;
    } catch (e) {
      print('Error formatting cell value: $e');
      return '';
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
}