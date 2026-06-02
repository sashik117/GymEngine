import 'package:flutter/services.dart';

const _channel = MethodChannel('gym_engine/external_link');

Future<void> openExternalLink(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return;
  }

  await _channel.invokeMethod<void>('openUrl', {'url': trimmed});
}
