// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_service.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingUploadAdapter extends TypeAdapter<PendingUpload> {
  @override
  final int typeId = 0;

  @override
  PendingUpload read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingUpload(
      boulderName: fields[0] as String,
      areaId: fields[1] as String,
      grade: fields[2] as String,
      latitude: fields[3] as double,
      longitude: fields[4] as double,
      boulderDescription: fields[5] as String,
      landmarkDescription: fields[6] as String,
      imageBytes: fields[7] as Uint8List?,
      imageFileExtension: fields[8] as String?,
      drawingData: (fields[9] as Map?)?.cast<String, dynamic>(),
      firstAscentUserId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PendingUpload obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.boulderName)
      ..writeByte(1)
      ..write(obj.areaId)
      ..writeByte(2)
      ..write(obj.grade)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.boulderDescription)
      ..writeByte(6)
      ..write(obj.landmarkDescription)
      ..writeByte(7)
      ..write(obj.imageBytes)
      ..writeByte(8)
      ..write(obj.imageFileExtension)
      ..writeByte(9)
      ..write(obj.drawingData)
      ..writeByte(10)
      ..write(obj.firstAscentUserId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingUploadAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
