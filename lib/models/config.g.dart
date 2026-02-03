// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EthereumConfigAdapter extends TypeAdapter<EthereumConfig> {
  @override
  final typeId = 0;

  @override
  EthereumConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EthereumConfig(
      rpcEndpoint: fields[0] as String,
      apiKey: fields[1] as String?,
      contractAddress: fields[2] as String,
      contractAbi: fields[3] as String,
      eventsToListen: (fields[4] as List).cast<String>(),
      startBlock: fields[5] == null ? 0 : (fields[5] as num).toInt(),
      lastBlock: (fields[6] as num?)?.toInt(),
      pollIntervalSeconds: fields[7] == null ? 5 : (fields[7] as num).toInt(),
      notificationsEnabled: fields[8] == null ? true : fields[8] as bool,
      blockExplorerUrl: fields[9] == null
          ? 'https://etherscan.io'
          : fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, EthereumConfig obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.rpcEndpoint)
      ..writeByte(1)
      ..write(obj.apiKey)
      ..writeByte(2)
      ..write(obj.contractAddress)
      ..writeByte(3)
      ..write(obj.contractAbi)
      ..writeByte(4)
      ..write(obj.eventsToListen)
      ..writeByte(5)
      ..write(obj.startBlock)
      ..writeByte(6)
      ..write(obj.lastBlock)
      ..writeByte(7)
      ..write(obj.pollIntervalSeconds)
      ..writeByte(8)
      ..write(obj.notificationsEnabled)
      ..writeByte(9)
      ..write(obj.blockExplorerUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EthereumConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
