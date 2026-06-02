import 'package:flutter/services.dart';

import 'photo_picker_base.dart';

const _photoPickerChannel = MethodChannel('gym_engine/photo_picker');

Future<PickedPhoto?> pickPhotoFromDevice() async {
  final Map<String, Object?>? result;
  try {
    result = await _photoPickerChannel.invokeMapMethod<String, Object?>(
      'pickPhoto',
    );
  } on MissingPluginException {
    return null;
  }
  if (result == null) {
    return null;
  }

  final rawBytes = result['bytes'];
  final bytes = switch (rawBytes) {
    Uint8List value => value,
    List<int> value => Uint8List.fromList(value),
    _ => Uint8List(0),
  };
  if (bytes.isEmpty) {
    return null;
  }

  return PickedPhoto(
    bytes: bytes,
    mimeType: result['mimeType']?.toString().trim().isEmpty == false
        ? result['mimeType'].toString()
        : 'image/jpeg',
  );
}
