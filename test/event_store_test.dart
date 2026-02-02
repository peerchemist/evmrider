import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:evmrider/services/event_store.dart';
import 'package:evmrider/models/config.dart';
import 'package:evmrider/models/event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  print('Starting test...');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('EventStore adds and loads events', () async {
    final config = EthereumConfig(
      rpcEndpoint: 'http://localhost:8545',
      contractAddress: '0x123',
      contractAbi: '[]',
      eventsToListen: ['Transfer'],
    );
    final event = Event(
      eventName: 'Transfer',
      transactionHash: '0xabc',
      blockNumber: 100,
      logIndex: 0,
      data: {'from': '0x1', 'to': '0x2', 'value': 100},
    );

    // Add event
    await EventStore.addEvent(config, event);

    // Load events async
    final events = await EventStore.load(config);
    expect(events.length, 1);
    expect(events.first.transactionHash, '0xabc');
    expect(events.first.data['value'], 100);

    // Load events sync via box
    final box = await Hive.openBox('events');
    final syncEvents = EventStore.loadSync(box, config);
    expect(syncEvents.length, 1);
    expect(syncEvents.first.transactionHash, '0xabc');
  });

  test('EventStore persists data across box close/open', () async {
    final config = EthereumConfig(
      rpcEndpoint: 'http://localhost:8545',
      contractAddress: '0x123',
      contractAbi: '[]',
      eventsToListen: ['Transfer'],
    );
    final event = Event(
      eventName: 'Transfer',
      transactionHash: '0xdef',
      blockNumber: 101,
      logIndex: 1,
      data: {},
    );

    await EventStore.addEvent(config, event);
    
    // Check it's there
    var events = await EventStore.load(config);
    expect(events.length, 1);

    // Close box
    await EventStore.closeBox();
    expect(Hive.isBoxOpen('events'), false);

    // Reopen and load
    events = await EventStore.load(config);
    expect(events.length, 1);
    expect(events.first.transactionHash, '0xdef');
  });
}
