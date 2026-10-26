import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/bootstrap.dart';
import 'app/private_note_app.dart';
import 'app/providers.dart';
import 'app/theme/appearance_controller.dart';
import 'foundation/platform/desktop_window_bootstrap.dart';
import 'foundation/platform/mobile_system_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 字体下载仅发生在用户选择非系统字体时；非遥测。
  GoogleFonts.config.allowRuntimeFetching = true;
  final prefs = await SharedPreferences.getInstance();
  final boot = await AppBootstrap.production();
  await DesktopWindowBootstrap.configureIfNeeded(boot.appHost);
  await MobileSystemUi.configureIfNeeded(boot.appHost);
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appHostProvider.overrideWithValue(boot.appHost),
        entryRepositoryProvider.overrideWithValue(boot.entryRepository),
        syncMetaRepositoryProvider.overrideWithValue(boot.syncMetaRepository),
        syncCredentialsStoreProvider.overrideWithValue(
          boot.syncCredentialsStore,
        ),
        syncEngineProvider.overrideWithValue(boot.syncEngine),
        appLockServiceProvider.overrideWithValue(boot.appLockService),
        biometricAuthProvider.overrideWithValue(boot.biometricAuth),
        screenProtectionProvider.overrideWithValue(boot.screenProtection),
      ],
      child: const PrivateNoteApp(),
    ),
  );
}
