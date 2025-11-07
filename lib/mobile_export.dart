import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models.dart';

class MobileExcelExporter {
  static Future<void> exportToExcel(
    List<Map<String, dynamic>> data,
    String fileName,
    BuildContext context,
  ) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission is required to export files');
      }

      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      if (data.isEmpty) {
        throw Exception('No data to export');
      }

      // Get headers from the first row
      final headers = data.first.keys.toList();

      // Write headers
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = headers[i];
      }

      // Write data
      for (int rowIndex = 0; rowIndex < data.length; rowIndex++) {
        final row = data[rowIndex];
        for (int colIndex = 0; colIndex < headers.length; colIndex++) {
          final value = row[headers[colIndex]];
          sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: colIndex,
            rowIndex: rowIndex + 1,
          ))
            ..value = value?.toString() ?? '';
        }
      }

      // Convert to bytes
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      // Get downloads directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create downloads folder if it doesn't exist
      final downloadsDir = Directory('${directory.path}/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Save file
      final file = File('${downloadsDir.path}/$fileName.xlsx');
      await file.writeAsBytes(bytes);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel file saved to: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                // You can add file opening logic here
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting Excel file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 