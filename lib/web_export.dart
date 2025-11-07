import 'dart:convert';
import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'models.dart';

class WebExcelExporter {
  static Future<void> exportToExcel(
    List<Map<String, dynamic>> data,
    String fileName,
    BuildContext context,
  ) async {
    try {
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

      // Create blob and download
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '$fileName.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel file exported successfully: $fileName.xlsx'),
            backgroundColor: Colors.green,
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