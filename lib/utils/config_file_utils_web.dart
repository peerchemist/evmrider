import 'dart:convert';
import 'dart:js_interop';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

Future<String?> pickYamlContent({String? dialogTitle}) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: dialogTitle,
    type: FileType.custom,
    allowedExtensions: ['yaml', 'yml'],
    withData: true,
  );

  if (result == null || result.files.isEmpty) return null;

  final bytes = result.files.single.bytes;
  if (bytes == null) return null;

  return utf8.decode(bytes, allowMalformed: true);
}

Future<String?> saveYamlFile(
  String yaml, {
  String? dialogTitle,
  required String fileName,
}) async {
  final blobParts = JSArray<web.BlobPart>()..add(yaml.toJS);
  final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'text/yaml'));
  final url = web.URL.createObjectURL(blob);

  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);

  return fileName;
}
