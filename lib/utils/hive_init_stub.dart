import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'package:evmrider/hive_registrar.g.dart';

Future<void> initHiveForAppImpl() async {
  await Hive.initFlutter();
  Hive.registerAdapters();
}
