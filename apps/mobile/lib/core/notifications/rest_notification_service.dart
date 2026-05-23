import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RestNotificationService {
  static const _channel = MethodChannel('gym_engine/rest_notifications');

  Future<void> initialize() async {
    await _invoke('initialize');
  }

  Future<void> requestPermission() async {
    await _invoke('requestPermission');
  }

  Future<void> scheduleRestComplete({
    required int seconds,
    required String title,
    required String body,
  }) async {
    await _invoke('scheduleRestComplete', {
      'seconds': seconds,
      'title': title,
      'body': body,
    });
  }

  Future<void> cancelRestComplete() async {
    await _invoke('cancelRestComplete');
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    if (kIsWeb) {
      return;
    }

    try {
      await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
