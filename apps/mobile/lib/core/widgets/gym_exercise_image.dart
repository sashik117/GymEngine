import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class GymExerciseImage extends StatelessWidget {
  const GymExerciseImage({
    required this.imageUrl,
    required this.fit,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
    super.key,
  });

  final String imageUrl;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final source = imageUrl.trim();
    if (_isImageDataUrl(source)) {
      final bytes = _decodeDataUrl(source);
      if (bytes == null) {
        return _fallback(context, FormatException('Invalid image data URL'));
      }
      return Image.memory(
        bytes,
        fit: fit,
        filterQuality: filterQuality,
        errorBuilder: errorBuilder,
      );
    }

    return Image.network(
      source,
      fit: fit,
      filterQuality: filterQuality,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: errorBuilder,
    );
  }

  Widget _fallback(BuildContext context, Object error) {
    return errorBuilder?.call(context, error, null) ?? SizedBox.shrink();
  }
}

bool isGymImageDataUrl(String value) => _isImageDataUrl(value.trim());

String gymImageDataUrlFromBytes({
  required Uint8List bytes,
  required String mimeType,
}) {
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}

bool _isImageDataUrl(String value) {
  return value.startsWith('data:image/') && value.contains(';base64,');
}

Uint8List? _decodeDataUrl(String value) {
  final commaIndex = value.indexOf(',');
  if (commaIndex < 0 || commaIndex == value.length - 1) {
    return null;
  }

  try {
    return base64Decode(value.substring(commaIndex + 1));
  } on FormatException {
    return null;
  }
}
