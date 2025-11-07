// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExcelDataAdapter extends TypeAdapter<ExcelData> {
  @override
  final int typeId = 1;

  @override
  ExcelData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExcelData(
      name: fields[0] as String,
      columns: (fields[1] as List).cast<String>(),
      rows: (fields[2] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      isCopy: fields[3] as bool,
      originalDatasetName: fields[4] as String?,
      originalRows: (fields[5] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          ?.toList(),
      updatedRowIndices: (fields[6] as List?)?.cast<int>(),
      newRowIndices: (fields[7] as List?)?.cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, ExcelData obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.columns)
      ..writeByte(2)
      ..write(obj.rows)
      ..writeByte(3)
      ..write(obj.isCopy)
      ..writeByte(4)
      ..write(obj.originalDatasetName)
      ..writeByte(5)
      ..write(obj.originalRows)
      ..writeByte(6)
      ..write(obj.updatedRowIndices)
      ..writeByte(7)
      ..write(obj.newRowIndices);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExcelDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
