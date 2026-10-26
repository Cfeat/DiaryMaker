import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';

import 'app_host.dart';

/// Desktop window setup via `window_manager` (Phase E).
///
/// Windows: custom chrome (hidden title bar).
/// macOS / Linux: native title bar + minimum size so narrow windows still usable.
class DesktopWindowBootstrap {
  DesktopWindowBootstrap._();

  static const minWindowSize = Size(720, 480);
  static const initialWindowSize = Size(1100, 720);

  static Future<void> configureIfNeeded(AppHost host) async {
    if (kIsWeb) return;
    if (!host.supportsDesktopShortcuts) return;

    await windowManager.ensureInitialized();

    if (host.usesCustomWindowChrome) {
      const options = WindowOptions(
        size: initialWindowSize,
        minimumSize: minWindowSize,
        center: true,
        backgroundColor: Color(0x00000000),
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        title: 'PrivateNote',
      );

      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setMinimumSize(minWindowSize);
        await windowManager.show();
        await windowManager.focus();
      });
      return;
    }

    // macOS / Linux: keep system chrome; still enforce min size + title.
    if (Platform.isMacOS || Platform.isLinux) {
      const options = WindowOptions(
        size: initialWindowSize,
        minimumSize: minWindowSize,
        center: true,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'PrivateNote',
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setMinimumSize(minWindowSize);
        await windowManager.setTitle('PrivateNote');
        await windowManager.show();
        await windowManager.focus();
      });
    }
  }
}
