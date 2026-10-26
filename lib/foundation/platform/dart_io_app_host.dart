import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'app_host.dart';

/// Production [AppHost] backed by `dart:io` [Platform].
class DartIoAppHost implements AppHost {
  const DartIoAppHost();

  @override
  bool get usesDesktopShell {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  @override
  bool get usesMobileShell {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  bool get supportsBiometrics => usesMobileShell;

  @override
  bool get supportsScreenProtection => usesMobileShell;

  @override
  bool get usesCustomWindowChrome {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  @override
  bool get supportsDesktopShortcuts {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }
}

/// Test / preview host with fixed capabilities.
class FakeAppHost implements AppHost {
  const FakeAppHost({
    this.usesDesktopShell = false,
    this.usesMobileShell = true,
    this.supportsBiometrics = true,
    this.supportsScreenProtection = false,
    this.usesCustomWindowChrome = false,
    this.supportsDesktopShortcuts = false,
  });

  @override
  final bool usesDesktopShell;

  @override
  final bool usesMobileShell;

  @override
  final bool supportsBiometrics;

  @override
  final bool supportsScreenProtection;

  @override
  final bool usesCustomWindowChrome;

  @override
  final bool supportsDesktopShortcuts;
}
