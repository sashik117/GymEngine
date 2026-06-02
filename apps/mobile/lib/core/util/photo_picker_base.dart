import 'dart:typed_data';

class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}
