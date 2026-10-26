import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'flutter_secure_storage_port.dart';
import 'key_manager.dart';
import 'secure_storage_key_manager.dart';
import 'secure_storage_port.dart';

/// Shared Android options: Keystore-backed RSA-OAEP + AES-GCM (plugin defaults).
AndroidOptions get _androidOptions => const AndroidOptions();

IOSOptions get _iosOptions =>
    const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

MacOsOptions get _macOsOptions =>
    const MacOsOptions(accessibility: KeychainAccessibility.first_unlock);

WindowsOptions get _windowsOptions => const WindowsOptions();

FlutterSecureStorage _storageFor({
  AndroidOptions? aOptions,
  IOSOptions? iOptions,
  MacOsOptions? mOptions,
  WindowsOptions? wOptions,
}) {
  return FlutterSecureStorage(
    aOptions: aOptions ?? _androidOptions,
    iOptions: iOptions ?? _iosOptions,
    mOptions: mOptions ?? _macOsOptions,
    wOptions: wOptions ?? _windowsOptions,
  );
}

/// Android: values protected via Android Keystore (plugin cipher stack).
class AndroidKeyManager extends SecureStorageKeyManager {
  AndroidKeyManager({SecureStoragePort? storage})
      : super(
          storage ??
              FlutterSecureStoragePort(
                _storageFor(aOptions: _androidOptions),
              ),
        );
}

/// iOS: Keychain via [FlutterSecureStorage].
class IosKeyManager extends SecureStorageKeyManager {
  IosKeyManager({SecureStoragePort? storage})
      : super(
          storage ??
              FlutterSecureStoragePort(
                _storageFor(iOptions: _iosOptions),
              ),
        );
}

/// macOS: Keychain via [FlutterSecureStorage].
class MacOsKeyManager extends SecureStorageKeyManager {
  MacOsKeyManager({SecureStoragePort? storage})
      : super(
          storage ??
              FlutterSecureStoragePort(
                _storageFor(mOptions: _macOsOptions),
              ),
        );
}

/// Windows: Credential Manager (+ encrypted app-support files) via plugin.
class WindowsKeyManager extends SecureStorageKeyManager {
  WindowsKeyManager({SecureStoragePort? storage})
      : super(
          storage ??
              FlutterSecureStoragePort(
                _storageFor(wOptions: _windowsOptions),
              ),
        );
}

/// Picks the platform [KeyManager] for the current OS.
KeyManager createPlatformKeyManager() {
  if (kIsWeb) {
    throw UnsupportedError('Web is not a target platform for PrivateNote');
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AndroidKeyManager();
    case TargetPlatform.iOS:
      return IosKeyManager();
    case TargetPlatform.macOS:
      return MacOsKeyManager();
    case TargetPlatform.windows:
      return WindowsKeyManager();
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      throw UnsupportedError(
        'Unsupported platform: $defaultTargetPlatform',
      );
  }
}

/// Same secure-storage backend as [createPlatformKeyManager] (PIN hashes, etc.).
SecureStoragePort createPlatformSecureStoragePort() {
  if (kIsWeb) {
    throw UnsupportedError('Web is not a target platform for PrivateNote');
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return FlutterSecureStoragePort(_storageFor(aOptions: _androidOptions));
    case TargetPlatform.iOS:
      return FlutterSecureStoragePort(_storageFor(iOptions: _iosOptions));
    case TargetPlatform.macOS:
      return FlutterSecureStoragePort(_storageFor(mOptions: _macOsOptions));
    case TargetPlatform.windows:
      return FlutterSecureStoragePort(_storageFor(wOptions: _windowsOptions));
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      throw UnsupportedError(
        'Unsupported platform: $defaultTargetPlatform',
      );
  }
}
