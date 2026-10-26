import 'package:flutter/material.dart';

/// Legacy placeholder — Phase C routes through [AdaptiveShell] via [LockGate].
@Deprecated('Use AdaptiveShell behind LockGate')
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('PrivateNote'),
      ),
    );
  }
}
