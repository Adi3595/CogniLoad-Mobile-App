// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_usage_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppUsageRecordAdapter extends TypeAdapter<AppUsageRecord> {
  @override
  final int typeId = 0;

  @override
  AppUsageRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppUsageRecord(
      packageName: fields[0] as String,
      appName: fields[1] as String,
      usageMinutes: fields[2] as int,
      date: fields[3] as DateTime,
      launchCount: fields[4] as int,
      category: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppUsageRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.packageName)
      ..writeByte(1)
      ..write(obj.appName)
      ..writeByte(2)
      ..write(obj.usageMinutes)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.launchCount)
      ..writeByte(5)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUsageRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionRecordAdapter extends TypeAdapter<SessionRecord> {
  @override
  final int typeId = 1;

  @override
  SessionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionRecord(
      packageName: fields[0] as String,
      appName: fields[1] as String,
      startTime: fields[2] as DateTime,
      endTime: fields[3] as DateTime?,
      alertSent: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SessionRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.packageName)
      ..writeByte(1)
      ..write(obj.appName)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.alertSent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CognitiveLoadSnapshotAdapter extends TypeAdapter<CognitiveLoadSnapshot> {
  @override
  final int typeId = 2;

  @override
  CognitiveLoadSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CognitiveLoadSnapshot(
      score: fields[0] as double,
      timestamp: fields[1] as DateTime,
      appUsageScore: fields[2] as double,
      sessionScore: fields[3] as double,
      lateNightScore: fields[4] as double,
      multitaskingScore: fields[5] as double,
      recommendations: (fields[6] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, CognitiveLoadSnapshot obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.score)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.appUsageScore)
      ..writeByte(3)
      ..write(obj.sessionScore)
      ..writeByte(4)
      ..write(obj.lateNightScore)
      ..writeByte(5)
      ..write(obj.multitaskingScore)
      ..writeByte(6)
      ..write(obj.recommendations);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CognitiveLoadSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
