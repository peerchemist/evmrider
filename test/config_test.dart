
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:evmrider/models/config.dart';
import 'dart:io';

void main() {
  group('EthereumConfig', () {
    setUp(() async {
      final path = Directory.systemTemp.createTempSync('hive_test').path;
      Hive.init(path);
    });
    
    tearDown(() async {
      await Hive.close();
    });

    test('defaults to etherscan', () {
      final config = EthereumConfig(
        rpcEndpoint: 'http://localhost',
        contractAddress: '0x123',
        contractAbi: '[]',
        eventsToListen: [],
      );
      expect(config.blockExplorerUrl, 'https://etherscan.io');
    });

    test('json serialization includes blockExplorerUrl', () {
      final config = EthereumConfig(
        rpcEndpoint: 'http://localhost',
        contractAddress: '0x123',
        contractAbi: '[]',
        eventsToListen: [],
        blockExplorerUrl: 'https://polygonscan.com',
      );
      final json = config.toJson();
      expect(json['blockExplorerUrl'], 'https://polygonscan.com');
      
      final fromJson = EthereumConfig.fromJson(json);
      expect(fromJson.blockExplorerUrl, 'https://polygonscan.com');
    });

    test('yaml serialization includes blockExplorerUrl', () {
      final config = EthereumConfig(
        rpcEndpoint: 'http://localhost',
        contractAddress: '0x123',
        contractAbi: '[]',
        eventsToListen: [],
        blockExplorerUrl: 'https://optimistic.etherscan.io',
      );
      final yaml = config.toYaml();
      expect(yaml, contains('blockExplorerUrl: https://optimistic.etherscan.io'));
      
      final fromYaml = EthereumConfig.fromYaml(yaml);
      expect(fromYaml?.blockExplorerUrl, 'https://optimistic.etherscan.io');
    });
    
    test('yaml serialization handles missing blockExplorerUrl (backward compatibility)', () {
      const yaml = '''
rpcEndpoint: http://localhost
contractAddress: 0x123
contractAbi: []
eventsToListen: []
''';
      final fromYaml = EthereumConfig.fromYaml(yaml);
      expect(fromYaml?.blockExplorerUrl, 'https://etherscan.io');
    });
  });
}
