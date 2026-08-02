import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_controller.dart';
import 'update_models.dart';

/// Shows [UpdateDialog] if there's something actionable to show.
///
/// [manual] distinguishes a user-triggered "Nach Updates suchen" click from
/// the silent startup check: the silent path only ever surfaces an actual
/// available update (never an error — a failed background check shouldn't
/// interrupt the user), and respects a previously dismissed version; the
/// manual path always shows both available updates and errors, and ignores
/// the dismissed-version memory since the user explicitly asked.
Future<void> maybeShowUpdateDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool manual,
}) async {
  final state = ref.read(updateControllerProvider);
  final showable = manual
      ? (state.phase == UpdatePhase.available || state.phase == UpdatePhase.error)
      : state.phase == UpdatePhase.available;
  if (!showable) return;

  if (!manual) {
    final dismissed = await ref.read(updatePrefsProvider).dismissedVersion();
    if (dismissed != null && dismissed == state.latestVersion) return;
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const UpdateDialog(),
  );
}

class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final controller = ref.read(updateControllerProvider.notifier);

    return AlertDialog(
      title: Text(_titleFor(state.phase)),
      content: _ContentFor(state: state),
      actions: _actionsFor(context, controller, state),
    );
  }

  String _titleFor(UpdatePhase phase) {
    switch (phase) {
      case UpdatePhase.available:
        return 'Update verfügbar';
      case UpdatePhase.downloading:
        return 'Wird heruntergeladen…';
      case UpdatePhase.readyToRelaunch:
        return 'Bereit zum Neustart';
      case UpdatePhase.applying:
        return 'Wird angewendet…';
      case UpdatePhase.error:
        return 'Update fehlgeschlagen';
      case UpdatePhase.idle:
      case UpdatePhase.checking:
      case UpdatePhase.upToDate:
        return 'Update';
    }
  }

  List<Widget> _actionsFor(
    BuildContext context,
    UpdateController controller,
    UpdateState state,
  ) {
    switch (state.phase) {
      case UpdatePhase.available:
        return [
          TextButton(
            onPressed: () async {
              await controller.dismiss();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Später'),
          ),
          FilledButton(
            onPressed: () => controller.downloadAndPrepare(),
            child: const Text('Herunterladen'),
          ),
        ];
      case UpdatePhase.readyToRelaunch:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Später'),
          ),
          FilledButton(
            onPressed: () => controller.confirmApply(),
            child: const Text('Jetzt neu starten'),
          ),
        ];
      case UpdatePhase.error:
        return [
          TextButton(
            onPressed: () {
              controller.reset();
              Navigator.of(context).pop();
            },
            child: const Text('Schließen'),
          ),
        ];
      case UpdatePhase.downloading:
      case UpdatePhase.applying:
      case UpdatePhase.idle:
      case UpdatePhase.checking:
      case UpdatePhase.upToDate:
        return const [];
    }
  }
}

class _ContentFor extends StatelessWidget {
  const _ContentFor({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    switch (state.phase) {
      case UpdatePhase.available:
        return SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${state.currentVersion} → ${state.latestVersion}'),
              if ((state.releaseNotes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(state.releaseNotes!.trim()),
                  ),
                ),
              ],
            ],
          ),
        );
      case UpdatePhase.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: state.downloadProgress),
            const SizedBox(height: 8),
            Text(
              state.downloadProgress != null
                  ? '${(state.downloadProgress! * 100).round()}%'
                  : '',
            ),
          ],
        );
      case UpdatePhase.readyToRelaunch:
        return const Text(
          'Das Update wurde heruntergeladen und geprüft. Beim Neustart wird die neue Version verwendet.',
        );
      case UpdatePhase.applying:
        return const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator()),
        );
      case UpdatePhase.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.errorMessage ?? 'Unbekannter Fehler.'),
            if (state.releaseUrl != null) ...[
              const SizedBox(height: 12),
              const Text('Manueller Download:'),
              SelectableText(state.releaseUrl!),
            ],
          ],
        );
      case UpdatePhase.idle:
      case UpdatePhase.checking:
      case UpdatePhase.upToDate:
        return const SizedBox.shrink();
    }
  }
}
