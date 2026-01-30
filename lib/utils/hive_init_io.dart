import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:evmrider/hive_registrar.g.dart';

Future<void> initHiveForAppImpl() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    final supportDir = await getApplicationSupportDirectory();
    Hive.init(supportDir.path);
  } else {
    await Hive.initFlutter();
  }

  Hive.registerAdapters();
}
