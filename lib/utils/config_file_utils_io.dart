import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<String?> pickYamlContent({String? dialogTitle}) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: dialogTitle,
    type: FileType.custom,
    allowedExtensions: ['yaml', 'yml'],
  );

  if (result == null || result.files.isEmpty) return null;

  final path = result.files.single.path;
  if (path == null) return null;

  return File(path).readAsString();
}

Future<String?> saveYamlFile(
  String yaml, {
  String? dialogTitle,
  required String fileName,
}) async {
  final outputFile = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['yaml', 'yml'],
  );

  if (outputFile == null) return null;

  final file = File(outputFile);
  await file.writeAsString(yaml);

  return outputFile;
}
