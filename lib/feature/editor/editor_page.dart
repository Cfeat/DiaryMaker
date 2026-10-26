import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/editor_save_gateway.dart';
import '../../app/providers.dart';
import '../../core/entry/entry.dart';

/// Plain-text title + body editor with 1s debounce autosave and discard confirm.
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({
    super.key,
    this.entryId,
    this.embedded = false,
    this.onSaved,
  });

  final String? entryId;
  final bool embedded;
  final VoidCallback? onSaved;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  Timer? _debounce;
  Entry? _entry;
  var _dirty = false;
  var _saving = false;
  var _loaded = false;
  String? _loadError;

  late final Future<void> Function() _saveHandler;
  EditorSaveGateway? _saveGateway;

  @override
  void initState() {
    super.initState();
    _saveHandler = _persistFromShortcut;
    _titleController.addListener(_onEdited);
    _bodyController.addListener(_onEdited);
    // Defer registration until first frame so [ref] is safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _saveGateway = ref.read(editorSaveGatewayProvider);
      _saveGateway!.register(_saveHandler);
    });
    _load();
  }

  Future<void> _persistFromShortcut() async {
    _debounce?.cancel();
    await _persist();
  }

  @override
  void didUpdateWidget(covariant EditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryId != widget.entryId) {
      _debounce?.cancel();
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loaded = false;
      _loadError = null;
      _dirty = false;
    });
    final id = widget.entryId;
    if (id == null) {
      final now = DateTime.now().toUtc();
      _entry = Entry(
        id: const Uuid().v4(),
        title: '',
        content: '',
        createdAt: now,
        updatedAt: now,
      );
      _titleController.text = '';
      _bodyController.text = '';
      setState(() => _loaded = true);
      return;
    }
    try {
      final found = await ref.read(entryRepositoryProvider).getById(id);
      if (found == null) {
        setState(() {
          _loadError = 'Entry not found';
          _loaded = true;
        });
        return;
      }
      _entry = found;
      _titleController.text = found.title;
      _bodyController.text = found.content;
      setState(() => _loaded = true);
    } catch (e) {
      setState(() {
        _loadError = '$e';
        _loaded = true;
      });
    }
  }

  void _onEdited() {
    if (!_loaded) return;
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), _autosave);
  }

  Future<void> _autosave() async {
    if (!_dirty || _entry == null) return;
    await _persist();
  }

  Future<void> _persist() async {
    final current = _entry;
    if (current == null || _saving) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toUtc();
      final next = current.copyWith(
        title: _titleController.text,
        content: _bodyController.text,
        updatedAt: now,
      );
      final repo = ref.read(entryRepositoryProvider);
      final existing = await repo.getById(next.id);
      if (existing == null) {
        await repo.create(next);
      } else {
        await repo.update(next);
      }
      try {
        await ref.read(syncMetaRepositoryProvider).touchLocalEdit(next.id);
      } catch (_) {
        // Sync meta optional in isolated editor tests without override.
      }
      _entry = next;
      _dirty = false;
      widget.onSaved?.call();
      await ref.read(timelineEntriesProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_dirty) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == 'cancel' || result == null) return false;
    if (result == 'save') {
      _debounce?.cancel();
      await _persist();
    }
    return true;
  }

  @override
  void dispose() {
    _saveGateway?.unregister(_saveHandler);
    _debounce?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_loadError!)),
      );
    }

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            key: const Key('editor_title_field'),
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (_saving)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('editor_body_field'),
              controller: _bodyController,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Write freely…',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          // Embedded: parent handles navigation; still flush debounce.
          if (_dirty) await _persist();
        },
        child: body,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDiscardIfNeeded();
        if (ok && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.entryId == null ? 'New entry' : 'Edit'),
          actions: [
            IconButton(
              key: const Key('editor_save_button'),
              tooltip: 'Save',
              onPressed: _saving
                  ? null
                  : () async {
                      _debounce?.cancel();
                      await _persist();
                    },
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}
