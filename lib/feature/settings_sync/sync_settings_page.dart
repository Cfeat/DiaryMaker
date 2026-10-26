import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/sync/sync_credentials_store.dart';
import '../../core/sync/sync_engine.dart';

/// User-supplied WebDAV only — no official cloud (§2.1).
class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _root = TextEditingController(text: '/privatenote/entries');
  var _obscure = true;
  var _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = await ref.read(syncCredentialsStoreProvider).read();
    if (existing == null || !mounted) return;
    setState(() {
      _url.text = existing.baseUrl;
      _user.text = existing.username;
      _password.text = existing.password;
      _root.text = existing.remoteRoot;
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _password.dispose();
    _root.dispose();
    super.dispose();
  }

  SyncCredentials _form() => SyncCredentials(
        baseUrl: _url.text,
        username: _user.text,
        password: _password.text,
        remoteRoot: _root.text,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Diary content is encrypted on this device with AES-256-GCM before '
            'upload. Your WebDAV server only stores ciphertext.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('sync_url_field'),
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'WebDAV URL',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('sync_username_field'),
            controller: _user,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('sync_password_field'),
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password / token',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _root,
            decoration: const InputDecoration(
              labelText: 'Remote folder',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('sync_save_button'),
            onPressed: _busy ? null : _save,
            child: const Text('Save credentials'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            key: const Key('sync_now_button'),
            onPressed: _busy ? null : _syncNow,
            child: const Text('Sync now'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!, key: const Key('sync_status_label')),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await ref.read(syncCredentialsStoreProvider).save(_form());
      setState(() => _status = 'Saved (password in secure storage)');
    } catch (e) {
      setState(() => _status = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _busy = true;
      _status = 'Syncing…';
    });
    try {
      final creds = _form();
      await ref.read(syncCredentialsStoreProvider).save(creds);
      final report =
          await ref.read(syncEngineProvider).synchronize(credentials: creds);
      await ref.read(timelineEntriesProvider.notifier).refresh();
      if (report.error != null) {
        setState(() => _status = 'Sync error: ${report.error}');
      } else if (report.hasConflicts) {
        final n = report.results
            .where((r) => r.action == SyncAction.conflict)
            .length;
        setState(
          () => _status =
              'Sync finished with $n conflict(s). Open the timeline to choose.',
        );
      } else {
        final pushed = report.results
            .where((r) => r.action == SyncAction.pushed)
            .length;
        final pulled = report.results
            .where((r) => r.action == SyncAction.pulled)
            .length;
        setState(
          () => _status = 'Sync OK — pushed $pushed, pulled $pulled',
        );
      }
    } catch (e) {
      setState(() => _status = 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
