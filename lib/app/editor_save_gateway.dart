import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets desktop shortcuts invoke the active editor's save without coupling UI.
class EditorSaveGateway extends ChangeNotifier {
  Future<void> Function()? _handler;

  void register(Future<void> Function() handler) {
    _handler = handler;
  }

  void unregister(Future<void> Function() handler) {
    if (_handler == handler) {
      _handler = null;
    }
  }

  Future<bool> requestSave() async {
    final handler = _handler;
    if (handler == null) return false;
    await handler();
    return true;
  }
}

final editorSaveGatewayProvider = ChangeNotifierProvider<EditorSaveGateway>(
  (ref) => EditorSaveGateway(),
);

class SaveEditorIntent extends Intent {
  const SaveEditorIntent();
}
