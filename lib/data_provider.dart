import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models.dart';

class DataProvider extends ChangeNotifier {
  static const String boxName = 'excelDataBox';
  Box<ExcelData>? _box;
  ExcelData? _excelData;
  String? _selectedName;
  bool _isInitialized = false;

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
    try {
      // Ensure the adapter is registered
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ExcelDataAdapter());
        print('ExcelDataAdapter registered in DataProvider');
      }
      
      // Hive is already initialized in main.dart, just open the box
      _box = await Hive.openBox<ExcelData>(boxName);
      if (_box!.isNotEmpty) {
        _excelData = _box!.getAt(0);
        _selectedName = _excelData!.name;
      }
      _isInitialized = true;
      notifyListeners();
      print('DataProvider initialized successfully');
    } catch (e) {
      print('Error opening Hive box: $e');
      _isInitialized = true; // Mark as initialized even if failed
      notifyListeners();
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _init();
    }
    // Wait a bit more if still not initialized
    int attempts = 0;
    while (!_isInitialized && attempts < 10) {
      await Future.delayed(Duration(milliseconds: 100));
      attempts++;
    }
  }

  Future<void> importExcelData(String name, List<String> columns, List<Map<String, dynamic>> rows) async {
    try {
      // Ensure storage is initialized
      await _ensureInitialized();

      // Validate only the name
      if (name == null || name.isEmpty) {
        throw Exception('Dataset name cannot be empty');
      }

      // Accept any columns (even empty)
      List<String> validColumns = [];
      if (columns != null && columns.isNotEmpty) {
        for (int i = 0; i < columns.length; i++) {
          String? col = columns[i];
          if (col == null || col.isEmpty) {
            col = 'Column ${i + 1}';
          }
          validColumns.add(col.trim());
        }
      } else {
        // If no columns provided, create a default one
        validColumns = ['Column 1'];
      }

      // Accept any rows (even empty)
      List<Map<String, dynamic>> validRows = [];
      if (rows != null && rows.isNotEmpty) {
        for (var row in rows) {
          if (row == null) {
            // Create empty row if null
            Map<String, dynamic> emptyRow = {};
            for (String col in validColumns) {
              emptyRow[col] = '';
            }
            validRows.add(emptyRow);
          } else {
            Map<String, dynamic> validRow = {};
            for (String col in validColumns) {
              dynamic value = row[col];
              if (value == null) {
                validRow[col] = '';
              } else {
                try {
                  validRow[col] = value.toString();
                } catch (e) {
                  validRow[col] = '';
                }
              }
            }
            validRows.add(validRow);
          }
        }
      } else {
        // If no rows provided, create one empty row
        Map<String, dynamic> emptyRow = {};
        for (String col in validColumns) {
          emptyRow[col] = '';
        }
        validRows.add(emptyRow);
      }

      // Ensure we have at least one row
      if (validRows.isEmpty) {
        Map<String, dynamic> emptyRow = {};
        for (String col in validColumns) {
          emptyRow[col] = '';
        }
        validRows.add(emptyRow);
      }

      final newData = ExcelData(name: name, columns: validColumns, rows: validRows);
      
      // Try to initialize box if not available
      if (_box == null) {
        await _init();
      }
      
      if (_box != null) {
        await _box!.add(newData);
        _excelData = newData;
        _selectedName = name;
        notifyListeners();
      } else {
        throw Exception('Storage not initialized');
      }
    } catch (e) {
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

  Future<void> copyDataset(String fromName, String newName) async {
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
      );
      await _box!.add(copy);
      _excelData = copy;
      _selectedName = newName;
      notifyListeners();
    }
  }

  Future<void> renameDataset(String oldName, String newName) async {
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
  }

  Future<void> deleteDataset(String name) async {
    await _ensureInitialized();
    final found = allDatasets.firstWhereOrNull((d) => d.name == name);
    if (found != null) {
      await found.delete();
      if (_selectedName == name) {
        if (_box!.isNotEmpty) {
          _excelData = _box!.getAt(0);
          _selectedName = _excelData!.name;
        } else {
          _excelData = null;
          _selectedName = null;
        }
      }
      notifyListeners();
    }
  }

  Future<void> addRow(Map<String, dynamic> row) async {
    await _ensureInitialized();
    if (_excelData != null) {
      _excelData!.rows.add(row);
      
      // Mark as new row if this is a copy
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
      
      // Mark as updated row if this is a copy
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
      
      // Update indices after deletion
      if (_excelData!.isCopy) {
        _excelData!.updatedRowIndices.removeWhere((i) => i == index);
        _excelData!.newRowIndices.removeWhere((i) => i == index);
        
        // Adjust indices for rows after the deleted row
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

  // Get changed rows for export (only for copied datasets)
  List<Map<String, dynamic>> get changedRows {
    if (_excelData != null && _excelData!.isCopy) {
      return _excelData!.changedRows;
    }
    return [];
  }

  // Check if current dataset is a copy
  bool get isCurrentDatasetCopy {
    return _excelData?.isCopy ?? false;
  }

  // Get row status for display
  String getRowStatus(int rowIndex) {
    if (_excelData != null && _excelData!.isCopy) {
      return _excelData!.getRowStatus(rowIndex);
    }
    return 'Original';
  }

  // Check if a row is changed
  bool isRowChanged(int rowIndex) {
    if (_excelData != null && _excelData!.isCopy) {
      return _excelData!.isRowChanged(rowIndex);
    }
    return false;
  }

  // Get change statistics
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

  // Get original dataset name for copied datasets
  String? get originalDatasetName {
    return _excelData?.originalDatasetName;
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