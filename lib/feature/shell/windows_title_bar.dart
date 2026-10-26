import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Custom Windows caption (replaces the default Flutter/OS title bar).
class WindowsTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const WindowsTitleBar({super.key, this.title = 'PrivateNote'});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kWindowCaptionHeight);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      height: kWindowCaptionHeight,
      child: WindowCaption(
        brightness: brightness,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(title),
      ),
    );
  }
}
