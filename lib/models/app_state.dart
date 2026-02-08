import 'package:hive_ce/hive.dart';

part 'app_state.g.dart';

@HiveType(typeId: 1)
class AppState extends HiveObject {
  @HiveField(0)
  int? lastProcessedBlock;

  @HiveField(1)
  int? backgroundPollFailures;

  AppState({
    this.lastProcessedBlock,
    this.backgroundPollFailures,
  });

  static Future<AppState> load() async {
    final box = await Hive.openBox<AppState>('state');
    return box.get('current') ?? AppState();
  }

  @override
  Future<void> save() async {
    final box = await Hive.openBox<AppState>('state');
    await box.put('current', this);
  }
}
