import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import 'update_controller.dart';
import 'update_dialog.dart';
import 'update_models.dart';

/// Settings-sheet section for the in-app updater: the "check automatically"
/// toggle plus a manual check button. Renders nothing on platforms the
/// updater doesn't support (Windows), so callers don't need to special-case
/// it.
class UpdateSettingsSection extends ConsumerWidget {
  const UpdateSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currentTargetPlatform() == UpdateTargetPlatform.unsupported) {
      return const SizedBox.shrink();
    }

    final settings = ref.watch(appSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          value: settings.updateCheckEnabled,
          onChanged: (value) async {
            final nextSettings = ref
                .read(appSettingsProvider)
                .copyWith(updateCheckEnabled: value);
            ref.read(appSettingsProvider.notifier).update(nextSettings);
            await saveAppSettings(nextSettings);
          },
          title: const Text('Automatisch nach Updates suchen'),
          subtitle: const Text(
            'Prüft beim Start einmal täglich auf eine neue Version.',
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _checkNow(context, ref),
            icon: const Icon(Icons.system_update_alt),
            label: const Text('Nach Updates suchen'),
          ),
        ),
      ],
    );
  }

  Future<void> _checkNow(BuildContext context, WidgetRef ref) async {
    await ref.read(updateControllerProvider.notifier).checkForUpdate();
    if (!context.mounted) return;

    final phase = ref.read(updateControllerProvider).phase;
    if (phase == UpdatePhase.upToDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Du hast bereits die neueste Version.')),
      );
      return;
    }
    await maybeShowUpdateDialog(context, ref, manual: true);
  }
}
