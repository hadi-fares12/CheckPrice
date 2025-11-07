import 'package:hive/hive.dart';
part 'models.g.dart';

@HiveType(typeId: 1)
class ExcelData extends HiveObject {
  @HiveField(0)
  late String name;
  @HiveField(1)
  late List<String> columns;
  @HiveField(2)
  late List<Map<String, dynamic>> rows;

  @HiveField(3)
  late bool isCopy;

  @HiveField(4)
  late String? originalDatasetName;

  @HiveField(5)
  late List<Map<String, dynamic>> originalRows;

  @HiveField(6)
  late List<int> updatedRowIndices;

  @HiveField(7)
  late List<int> newRowIndices;

  ExcelData({
    required this.name, 
    required this.columns, 
    required this.rows,
    this.isCopy = false,
    this.originalDatasetName,
    List<Map<String, dynamic>>? originalRows,
    List<int>? updatedRowIndices,
    List<int>? newRowIndices,
  }) : 
    originalRows = originalRows ?? [],
    updatedRowIndices = updatedRowIndices ?? [],
    newRowIndices = newRowIndices ?? [];

  // Get only the changed rows (updated + new)
  List<Map<String, dynamic>> get changedRows {
    List<Map<String, dynamic>> changed = [];
    
    // Add updated rows
    for (int index in updatedRowIndices) {
      if (index < rows.length) {
        changed.add(rows[index]);
      }
    }
    
    // Add new rows
    for (int index in newRowIndices) {
      if (index < rows.length) {
        changed.add(rows[index]);
      }
    }
    
    return changed;
  }

  // Check if a row is changed (updated or new)
  bool isRowChanged(int rowIndex) {
    return updatedRowIndices.contains(rowIndex) || newRowIndices.contains(rowIndex);
  }

  // Mark a row as updated
  void markRowAsUpdated(int rowIndex) {
    if (!updatedRowIndices.contains(rowIndex) && !newRowIndices.contains(rowIndex)) {
      updatedRowIndices.add(rowIndex);
      save();
    }
  }

  // Mark a row as new
  void markRowAsNew(int rowIndex) {
    if (!newRowIndices.contains(rowIndex)) {
      newRowIndices.add(rowIndex);
      save();
    }
  }

  // Get row status for display
  String getRowStatus(int rowIndex) {
    if (newRowIndices.contains(rowIndex)) {
      return 'New';
    } else if (updatedRowIndices.contains(rowIndex)) {
      return 'Updated';
    } else {
      return 'Original';
    }
  }
} 