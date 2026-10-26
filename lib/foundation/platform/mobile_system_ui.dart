import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_host.dart';

/// Mobile edge-to-edge / status bar polish (Phase E). No telemetry.
abstract final class MobileSystemUi {
  static Future<void> configureIfNeeded(AppHost host) async {
    if (!host.usesMobileShell) return;

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
}
