import 'package:hive_ce_flutter/hive_ce_flutter.dart';

Future<void> initHiveForAppImpl() async {
  await Hive.initFlutter();
}
