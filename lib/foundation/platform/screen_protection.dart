/// Screenshot / recent-apps leakage protection (mobile).
abstract class ScreenProtection {
  Future<void> enable();

  Future<void> disable();
}

class NoOpScreenProtection implements ScreenProtection {
  const NoOpScreenProtection();

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}
