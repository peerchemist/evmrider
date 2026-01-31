import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

import 'package:evmrider/models/config.dart';
import 'package:evmrider/models/event.dart';

class EventStore {
  static const String _boxName = 'events';
  static const String _defaultKey = 'events';

  static Future<List<Event>> load(
    EthereumConfig? config, {
    int limit = 32,
  }) async {
    final box = await Hive.openBox(_boxName);
    final key = _keyForConfig(config);
    final events = _decodeEvents(box.get(key));
    if (limit > 0 && events.length > limit) {
      return events.sublist(0, limit);
    }
    return events;
  }

  static Future<void> addEvent(
    EthereumConfig? config,
    Event event, {
    int maxEvents = 200,
  }) async {
    await addEvents(config, [event], maxEvents: maxEvents);
  }

  static Future<void> addEvents(
    EthereumConfig? config,
    List<Event> events, {
    int maxEvents = 200,
  }) async {
    if (events.isEmpty) return;

    final box = await Hive.openBox(_boxName);
    final key = _keyForConfig(config);

    final existing = _decodeEvents(box.get(key));
    final seen = existing.map(_eventId).toSet();

    final sorted = List<Event>.from(events)
      ..sort((a, b) => a.blockNumber.compareTo(b.blockNumber));

    for (final event in sorted) {
      if (seen.add(_eventId(event))) {
        existing.insert(0, event);
      }
    }

    if (maxEvents > 0 && existing.length > maxEvents) {
      existing.removeRange(maxEvents, existing.length);
    }

    final encoded = existing.map(_encodeEvent).toList(growable: false);
    await box.put(key, encoded);
  }

  static Future<void> clear(EthereumConfig? config) async {
    final box = await Hive.openBox(_boxName);
    final key = _keyForConfig(config);
    await box.delete(key);
  }

  static Future<void> removeEvent(
    EthereumConfig? config,
    Event event,
  ) async {
    final box = await Hive.openBox(_boxName);
    final key = _keyForConfig(config);
    final existing = _decodeEvents(box.get(key));
    final targetId = _eventId(event);
    final filtered = existing
        .where((entry) => _eventId(entry) != targetId)
        .toList(growable: false);
    if (filtered.length == existing.length) return;
    final encoded = filtered.map(_encodeEvent).toList(growable: false);
    await box.put(key, encoded);
  }

  static String _keyForConfig(EthereumConfig? config) {
    if (config == null) return _defaultKey;
    final raw = [
      config.rpcEndpoint,
      config.contractAddress.toLowerCase(),
      config.eventsToListen.join(','),
    ].join('|');
    final encoded = base64Url.encode(utf8.encode(raw));
    return 'events:$encoded';
  }

  static String _eventId(Event event) =>
      '${event.eventName}|${event.blockNumber}|${event.transactionHash}|${event.logIndex}';

  static List<Event> _decodeEvents(dynamic raw) {
    if (raw is! List) return <Event>[];

    final events = <Event>[];
    for (final entry in raw) {
      if (entry is Map) {
        events.add(_decodeEvent(entry));
      }
    }
    return events;
  }

  static Event _decodeEvent(Map<dynamic, dynamic> raw) {
    final name = raw['eventName']?.toString() ?? '';
    final txHash = raw['transactionHash']?.toString() ?? 'unknown';

    var blockNumber = 0;
    final rawBlock = raw['blockNumber'];
    if (rawBlock is int) {
      blockNumber = rawBlock;
    } else if (rawBlock is num) {
      blockNumber = rawBlock.toInt();
    } else if (rawBlock is String) {
      blockNumber = int.tryParse(rawBlock) ?? 0;
    }

    var logIndex = 0;
    final rawLogIndex = raw['logIndex'];
    if (rawLogIndex is int) {
      logIndex = rawLogIndex;
    } else if (rawLogIndex is num) {
      logIndex = rawLogIndex.toInt();
    } else if (rawLogIndex is String) {
      logIndex = int.tryParse(rawLogIndex) ?? 0;
    }

    final data = _normalizeMap(raw['data']);

    return Event(
      eventName: name,
      transactionHash: txHash,
      blockNumber: blockNumber,
      logIndex: logIndex,
      data: data,
    );
  }

  static Map<String, dynamic> _encodeEvent(Event event) {
    return {
      'eventName': event.eventName,
      'transactionHash': event.transactionHash,
      'blockNumber': event.blockNumber,
      'logIndex': event.logIndex,
      'data': _encodeValue(event.data),
    };
  }

  static Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    final out = <String, dynamic>{};
    value.forEach((key, value) {
      out[key.toString()] = _normalizeValue(value);
    });
    return out;
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value is List) {
      return value.map(_normalizeValue).toList();
    }
    if (value is Map) {
      return _normalizeMap(value);
    }
    return value;
  }

  static dynamic _encodeValue(dynamic value) {
    if (value == null) return null;
    if (value is num || value is bool || value is String) return value;
    if (value is BigInt) return value.toString();
    if (value is Uint8List) return value.toList();
    if (value is List) return value.map(_encodeValue).toList();
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, value) {
        out[key.toString()] = _encodeValue(value);
      });
      return out;
    }

    final hex = _tryHex(value);
    if (hex != null) return hex;

    return value.toString();
  }

  static String? _tryHex(dynamic value) {
    try {
      final hex = (value as dynamic).hex;
      if (hex is String) return hex;
    } catch (_) {}

    try {
      final hexEip55 = (value as dynamic).hexEip55;
      if (hexEip55 is String) return hexEip55;
    } catch (_) {}

    return null;
  }
}
