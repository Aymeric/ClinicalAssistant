import 'dart:io';

import 'package:flutter/services.dart';

class LocalVaultDirectory {
  static const _channel = MethodChannel('clinical_assistant/local_data');

  static Future<Directory> resolve() async {
    final path = await _channel.invokeMethod<String>('vaultDirectory');
    if (path == null || path.isEmpty) {
      throw StateError(
        'The operating system did not provide a local vault directory.',
      );
    }
    return Directory(path);
  }
}
