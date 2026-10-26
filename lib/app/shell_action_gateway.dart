import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Desktop shortcuts → shell actions (new entry, focus timeline) without UI coupling.
class ShellActionGateway extends ChangeNotifier {
  VoidCallback? _onNewEntry;
  VoidCallback? _onFocusTimeline;

  void registerNewEntry(VoidCallback handler) {
    _onNewEntry = handler;
  }

  void unregisterNewEntry(VoidCallback handler) {
    if (_onNewEntry == handler) _onNewEntry = null;
  }

  void registerFocusTimeline(VoidCallback handler) {
    _onFocusTimeline = handler;
  }

  void unregisterFocusTimeline(VoidCallback handler) {
    if (_onFocusTimeline == handler) _onFocusTimeline = null;
  }

  bool requestNewEntry() {
    final h = _onNewEntry;
    if (h == null) return false;
    h();
    return true;
  }

  bool requestFocusTimeline() {
    final h = _onFocusTimeline;
    if (h == null) return false;
    h();
    return true;
  }
}

final shellActionGatewayProvider =
    ChangeNotifierProvider<ShellActionGateway>((ref) => ShellActionGateway());

class NewEntryIntent extends Intent {
  const NewEntryIntent();
}

class FocusTimelineIntent extends Intent {
  const FocusTimelineIntent();
}
