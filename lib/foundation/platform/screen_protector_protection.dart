import 'package:screen_protector/screen_protector.dart';

import 'screen_protection.dart';

/// Mobile implementation via `package:screen_protector`
/// (Android FLAG_SECURE + iOS secure / blur equivalent).
class ScreenProtectorProtection implements ScreenProtection {
  @override
  Future<void> enable() async {
    await ScreenProtector.protectDataLeakageOn();
    await ScreenProtector.preventScreenshotOn();
  }

  @override
  Future<void> disable() async {
    await ScreenProtector.protectDataLeakageOff();
    await ScreenProtector.preventScreenshotOff();
  }
}
