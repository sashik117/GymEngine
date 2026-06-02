import 'dart:js_interop';

@JS('window.open')
external JSAny? _windowOpen(JSString url, JSString target);

Future<void> openExternalLink(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return;
  }

  _windowOpen(trimmed.toJS, '_blank'.toJS);
}
