import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> pickYamlContent({String? dialogTitle}) async {
  final result = await FilePicker.pickFiles(
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
  final yamlBytes = Uint8List.fromList(utf8.encode(yaml));
  final outputFile = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['yaml', 'yml'],
    bytes: yamlBytes,
  );

  if (outputFile == null) return null;

  return outputFile;
}
