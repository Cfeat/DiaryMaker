import 'package:flutter/material.dart';

import '../../app/l10n/app_strings.dart';
import '../settings_sync/sync_settings_page.dart';
import 'appearance_settings_page.dart';

class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            key: const Key('settings_appearance'),
            leading: const Icon(Icons.font_download_outlined),
            title: const Text(S.settingsAppearance),
            subtitle: const Text('字体、色调'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppearanceSettingsPage(),
                ),
              );
            },
          ),
          ListTile(
            key: const Key('settings_sync'),
            leading: const Icon(Icons.cloud_outlined),
            title: const Text(S.settingsSync),
            subtitle: const Text('端到端加密 · 自备 WebDAV'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SyncSettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
