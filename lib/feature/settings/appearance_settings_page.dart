import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/theme/appearance_controller.dart';
import '../../app/theme/font_option.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceControllerProvider);
    final ctrl = ref.read(appearanceControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(S.appearanceTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            S.appearanceThemeSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mood in AppColorMood.values)
                ChoiceChip(
                  key: Key('mood_${mood.id}'),
                  selected: appearance.mood == mood,
                  label: Text(mood.labelZh),
                  onSelected: (_) => ctrl.setMood(mood),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            S.appearanceFontSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            S.appearanceFontHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          for (final font in AppFontOption.values)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                key: Key('font_${font.id}'),
                selected: appearance.font == font,
                leading: Icon(
                  appearance.font == font
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                onTap: () => ctrl.setFont(font),
                title: Text(font.labelZh),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(font.subtitleZh),
                    const SizedBox(height: 8),
                    Text(
                      S.appearancePreview,
                      style: font.previewStyle(fontSize: 17),
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }
}
