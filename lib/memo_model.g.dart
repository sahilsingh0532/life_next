// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memo_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MemoAdapter extends TypeAdapter<Memo> {
  @override
  final int typeId = 0;

  @override
  Memo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Memo(
      text: fields[0] as String,
      imagePath: fields[1] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Memo obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.imagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
