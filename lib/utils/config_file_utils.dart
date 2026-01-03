import 'config_file_utils_io.dart'
    if (dart.library.html) 'config_file_utils_web.dart' as platform;

Future<String?> pickYamlContent({String? dialogTitle}) {
  return platform.pickYamlContent(dialogTitle: dialogTitle);
}

Future<String?> saveYamlFile(
  String yaml, {
  String? dialogTitle,
  required String fileName,
}) {
  return platform.saveYamlFile(
    yaml,
    dialogTitle: dialogTitle,
    fileName: fileName,
  );
}
