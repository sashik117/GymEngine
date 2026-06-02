// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'photo_picker_base.dart';

Future<PickedPhoto?> pickPhotoFromDevice() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  input.click();
  await input.onChange.first;

  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) {
    return null;
  }

  final reader = html.FileReader()..readAsArrayBuffer(file);
  await reader.onLoad.first;

  final result = reader.result;
  final bytes = switch (result) {
    ByteBuffer buffer => buffer.asUint8List(),
    Uint8List list => list,
    List<int> list => Uint8List.fromList(list),
    _ => Uint8List(0),
  };

  if (bytes.isEmpty) {
    return null;
  }

  return PickedPhoto(
    bytes: bytes,
    mimeType: file.type.trim().isEmpty ? 'image/jpeg' : file.type,
  );
}
