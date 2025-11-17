import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:excel/excel.dart';

class DataProvider extends ChangeNotifier {
  static const String boxName = 'excelDataBox';
  Box<ExcelData>? _box;
  ExcelData? _excelData;
  String? _selectedName;
  bool _isInitialized = false;
  bool _initializationInProgress = false;

  List<ExcelData> get allDatasets => _box?.values.toList() ?? [];
  List<String> get datasetNames => allDatasets.map((e) => e.name).toList();
  String? get selectedName => _selectedName;
  bool get isInitialized => _isInitialized;

  List<String> get columns => _excelData?.columns ?? [];
  List<Map<String, dynamic>> get rows => _excelData?.rows ?? [];

  DataProvider() {
    _init();
  }

  Future<void> _init() async {
    if (_initializationInProgress) return;
    
    _initializationInProgress = true;
    try {
      print('Initializing DataProvider...');
      
      // Ensure the adapter is registered
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ExcelDataAdapter());
        print('ExcelDataAdapter registered in DataProvider');
      }
      
      // Open the Hive box with better error handling
      try {
        _box = await Hive.openBox<ExcelData>(boxName);
        print('Hive box opened successfully');
      } catch (e) {
        print('Error opening Hive box: $e');
        
        // FIXED: Better error handling for corrupted data
        if (e.toString().contains('type') && e.toString().contains('subtype')) {
          print('Detected schema mismatch. Clearing corrupted data...');
          
          try {
            // Close any open boxes first
            if (Hive.isBoxOpen(boxName)) {
              await Hive.box<ExcelData>(boxName).close();
            }
            
            // Delete the corrupted box
            await Hive.deleteBoxFromDisk(boxName);
            print('Deleted corrupted box');
            
            // Create a fresh box
            _box = await Hive.openBox<ExcelData>(boxName);
            print('Created fresh box after data corruption');
          } catch (deleteError) {
            print('Error during box recreation: $deleteError');
            
            // Last resort: try to manually delete the file
            try {
              final boxPath = '${Directory.current.path}/exceldatabox.hive';
              final file = File(boxPath);
              if (await file.exists()) {
                // Try to force unlock by waiting
                await Future.delayed(Duration(milliseconds: 500));
                await file.delete();
                print('Manually deleted box file');
              }
              
              _box = await Hive.openBox<ExcelData>(boxName);
              print('Box recreated after manual deletion');
            } catch (manualError) {
              print('Manual deletion failed: $manualError');
              throw Exception('Failed to initialize storage. Please restart the application.');
            }
          }
        } else {
          throw Exception('Failed to initialize storage: $e');
        }
      }
      
      // Load existing data if available
      if (_box != null && _box!.isNotEmpty) {
        try {
          _excelData = _box!.values.first;
          _selectedName = _excelData!.name;
          print('Loaded existing dataset: ${_excelData!.name}');
        } catch (loadError) {
          print('Error loading existing data: $loadError');
          // Clear corrupted data
          await _box!.clear();
          print('Cleared corrupted existing data');
        }
      }
      
      _isInitialized = true;
      notifyListeners();
      print('DataProvider initialized successfully');
    } catch (e) {
      print('Error initializing DataProvider: $e');
      _isInitialized = true; // Mark as initialized to prevent blocking
      notifyListeners();
      rethrow;
    } finally {
      _initializationInProgress = false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized && _box != null) return;
    
    // Wait for initialization to complete
    int attempts = 0;
    while (!_isInitialized && attempts < 50) {
      await Future.delayed(Duration(milliseconds: 100));
      attempts++;
    }
    
    if (!_isInitialized) {
      throw Exception('DataProvider initialization timeout');
    }
    
    if (_box == null) {
      throw Exception('Storage not available');
    }
  }

  Future<void> importExcelData(
    String name, 
    List<String> columns, 
    List<Map<String, dynamic>> rows, 
    {String? importPath, bool autoRefresh = false}
  ) async {
    try {
      print('Starting import for dataset: $name');
      
      await _ensureInitialized();

      if (name.trim().isEmpty) {
        throw Exception('Dataset name cannot be empty');
      }

      List<String> validColumns = [];
      if (columns.isNotEmpty) {
        for (int i = 0; i < columns.length; i++) {
          String col = columns[i];
          if (col.isEmpty) {
            col = 'Column ${i + 1}';
          }
          validColumns.add(col.trim());
        }
      } else {
        validColumns = ['Column 1'];
      }

      List<Map<String, dynamic>> validRows = [];
      if (rows.isNotEmpty) {
        for (var row in rows) {
          Map<String, dynamic> validRow = {};
          for (String col in validColumns) {
            try {
              dynamic value = row[col];
              if (value == null) {
                validRow[col] = '';
              } else {
                validRow[col] = value.toString();
              }
            } catch (e) {
              validRow[col] = '';
            }
          }
          validRows.add(validRow);
        }
      } else {
        Map<String, dynamic> emptyRow = {};
        for (String col in validColumns) {
          emptyRow[col] = '';
        }
        validRows.add(emptyRow);
      }

      final existingIndex = allDatasets.indexWhere((d) => d.name == name);
      
      ExcelData newData;
      if (existingIndex != -1) {
        newData = allDatasets[existingIndex];
        newData.columns = validColumns;
        newData.rows = validRows;
        newData.importPath = importPath;
        newData.autoRefresh = autoRefresh;
        await newData.save();
        print('Updated existing dataset: $name');
      } else {
        newData = ExcelData(
          name: name, 
          columns: validColumns, 
          rows: validRows,
          importPath: importPath,
          autoRefresh: autoRefresh,
        );
        
        await _box!.add(newData);
        print('Created new dataset: $name');
      }

      _excelData = newData;
      _selectedName = name;
      notifyListeners();
      
      print('Import completed successfully for dataset: $name');
    } catch (e) {
      print('Error in importExcelData: $e');
      throw Exception('Import failed: ${e.toString()}');
    }
  }

  void selectDataset(String name) {
    final found = allDatasets.firstWhereOrNull((d) => d.name == name);
    if (found != null) {
      _excelData = found;
      _selectedName = name;
      notifyListeners();
    }
  }

  Future<void> deleteDataset(String name) async {
    try {
      await _ensureInitialized();
      final found = allDatasets.firstWhereOrNull((d) => d.name == name);
      if (found != null) {
        await found.delete();
        if (_selectedName == name) {
          if (_box!.isNotEmpty) {
            _excelData = _box!.values.first;
            _selectedName = _excelData!.name;
          } else {
            _excelData = null;
            _selectedName = null;
          }
        }
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to delete dataset: ${e.toString()}');
    }
  }

  Future<void> copyDataset(String fromName, String newName) async {
    try {
      await _ensureInitialized();
      final found = allDatasets.firstWhereOrNull((d) => d.name == fromName);
      if (found != null) {
        final copy = ExcelData(
          name: newName,
          columns: List<String>.from(found.columns),
          rows: List<Map<String, dynamic>>.from(found.rows.map((row) => Map<String, dynamic>.from(row))),
          isCopy: true,
          originalDatasetName: fromName,
          originalRows: List<Map<String, dynamic>>.from(found.rows.map((row) => Map<String, dynamic>.from(row))),
          updatedRowIndices: [],
          newRowIndices: [],
          importPath: found.importPath,
          autoRefresh: found.autoRefresh,
        );
        await _box!.add(copy);
        _excelData = copy;
        _selectedName = newName;
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to copy dataset: ${e.toString()}');
    }
  }

  Future<void> renameDataset(String oldName, String newName) async {
    try {
      await _ensureInitialized();
      final found = allDatasets.firstWhereOrNull((d) => d.name == oldName);
      if (found != null) {
        found.name = newName;
        await found.save();
        if (_selectedName == oldName) {
          _selectedName = newName;
        }
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to rename dataset: ${e.toString()}');
    }
  }

  Future<void> addRow(Map<String, dynamic> row) async {
    await _ensureInitialized();
    if (_excelData != null) {
      _excelData!.rows.add(row);
      
      if (_excelData!.isCopy) {
        _excelData!.markRowAsNew(_excelData!.rows.length - 1);
      }
      
      await _excelData!.save();
      notifyListeners();
    }
  }

  Future<void> updateRow(int index, Map<String, dynamic> row) async {
    await _ensureInitialized();
    if (_excelData != null && index >= 0 && index < _excelData!.rows.length) {
      _excelData!.rows[index] = row;
      
      if (_excelData!.isCopy) {
        _excelData!.markRowAsUpdated(index);
      }
      
      await _excelData!.save();
      notifyListeners();
    }
  }

  Future<void> deleteRow(int index) async {
    await _ensureInitialized();
    if (_excelData != null && index >= 0 && index < _excelData!.rows.length) {
      _excelData!.rows.removeAt(index);
      
      if (_excelData!.isCopy) {
        _excelData!.updatedRowIndices.removeWhere((i) => i == index);
        _excelData!.newRowIndices.removeWhere((i) => i == index);
        
        _excelData!.updatedRowIndices = _excelData!.updatedRowIndices
            .where((i) => i != index)
            .map((i) => i > index ? i - 1 : i)
            .toList();
        _excelData!.newRowIndices = _excelData!.newRowIndices
            .where((i) => i != index)
            .map((i) => i > index ? i - 1 : i)
            .toList();
      }
      
      await _excelData!.save();
      notifyListeners();
    }
  }

  Future<void> updateColumns(List<String> newColumns) async {
    await _ensureInitialized();
    if (_excelData != null) {
      List<Map<String, dynamic>> newRows = _excelData!.rows.map((row) {
        Map<String, dynamic> newRow = {};
        for (int i = 0; i < newColumns.length; i++) {
          String oldCol = i < _excelData!.columns.length ? _excelData!.columns[i] : '';
          newRow[newColumns[i]] = row[oldCol] ?? '';
        }
        return newRow;
      }).toList();
      _excelData!.columns = newColumns;
      _excelData!.rows = newRows;
      await _excelData!.save();
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> search(String query) {
    if (_excelData == null) return [];
    return _excelData!.rows.where((row) {
      return row.values.any((v) => v != null && v.toString().toLowerCase().contains(query.toLowerCase()));
    }).toList();
  }

  Future<void> clearAll() async {
    await _ensureInitialized();
    await _box!.clear();
    _excelData = null;
    _selectedName = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> get changedRows {
    if (_excelData != null && _excelData!.isCopy) {
      return _excelData!.changedRows;
    }
    return [];
  }

  bool get isCurrentDatasetCopy {
    return _excelData?.isCopy ?? false;
  }

  String getRowStatus(int rowIndex) {
    if (_excelData != null && _excelData!.isCopy) {
      return _excelData!.getRowStatus(rowIndex);
    }
    return 'Original';
  }

  bool isRowChanged(int rowIndex) {
    if (_excelData != null && _excelData!.isCopy) {
      return _excelData!.isRowChanged(rowIndex);
    }
    return false;
  }

  Map<String, int> get changeStats {
    if (_excelData != null && _excelData!.isCopy) {
      return {
        'total': _excelData!.rows.length,
        'original': _excelData!.rows.length - _excelData!.updatedRowIndices.length - _excelData!.newRowIndices.length,
        'updated': _excelData!.updatedRowIndices.length,
        'new': _excelData!.newRowIndices.length,
        'changed': _excelData!.changedRows.length,
      };
    }
    return {
      'total': _excelData?.rows.length ?? 0,
      'original': _excelData?.rows.length ?? 0,
      'updated': 0,
      'new': 0,
      'changed': 0,
    };
  }

  String? get originalDatasetName {
    return _excelData?.originalDatasetName;
  }

  List<ExcelData> get refreshableDatasets {
    return allDatasets.where((dataset) => dataset.canRefresh).toList();
  }
}

extension FirstWhereOrNullExtension<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}