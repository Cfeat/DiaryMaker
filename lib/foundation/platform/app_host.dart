/// Platform capability facade — UI must not scatter [Platform.isX] checks (C4).
abstract class AppHost {
  /// Windows / macOS shell: sidebar + content.
  bool get usesDesktopShell;

  /// Android / iOS shell: bottom nav or single stack.
  bool get usesMobileShell;

  /// Biometric unlock offered only on mobile (PIN remains on all platforms).
  bool get supportsBiometrics;

  /// Screenshot / app-switcher protection (mobile FLAG_SECURE / iOS equivalent).
  bool get supportsScreenProtection;

  /// Windows custom title bar via window_manager (Phase E).
  bool get usesCustomWindowChrome;

  /// Desktop keyboard chord shortcuts (e.g. Ctrl+S) when the app is focused.
  bool get supportsDesktopShortcuts;
}
