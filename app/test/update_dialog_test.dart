import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/update/update_controller.dart';
import 'package:qwirkle_digital/src/update/update_dialog.dart';
import 'package:qwirkle_digital/src/update/update_models.dart';

class _FixedUpdateController extends UpdateController {
  _FixedUpdateController(this._initial);

  final UpdateState _initial;

  @override
  UpdateState build() => _initial;
}

Future<void> _pumpDialog(WidgetTester tester, UpdateState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updateControllerProvider.overrideWith(() => _FixedUpdateController(state)),
      ],
      child: const MaterialApp(home: Scaffold(body: UpdateDialog())),
    ),
  );
}

void main() {
  testWidgets('available phase shows version and actions', (tester) async {
    await _pumpDialog(
      tester,
      const UpdateState(
        phase: UpdatePhase.available,
        currentVersion: '0.3.0',
        latestVersion: 'v0.4.0',
        releaseNotes: 'Neue Features',
      ),
    );

    expect(find.text('Update verfügbar'), findsOneWidget);
    expect(find.text('0.3.0 → v0.4.0'), findsOneWidget);
    expect(find.text('Herunterladen'), findsOneWidget);
    expect(find.text('Später'), findsOneWidget);
  });

  testWidgets('downloading phase shows progress', (tester) async {
    await _pumpDialog(
      tester,
      const UpdateState(phase: UpdatePhase.downloading, downloadProgress: 0.5),
    );

    expect(find.text('Wird heruntergeladen…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('readyToRelaunch phase offers a restart button', (tester) async {
    await _pumpDialog(tester, const UpdateState(phase: UpdatePhase.readyToRelaunch));

    expect(find.text('Bereit zum Neustart'), findsOneWidget);
    expect(find.text('Jetzt neu starten'), findsOneWidget);
  });

  testWidgets('error phase shows the error message and a fallback link', (tester) async {
    await _pumpDialog(
      tester,
      const UpdateState(
        phase: UpdatePhase.error,
        errorMessage: 'Etwas ist schiefgelaufen.',
        releaseUrl: 'https://example.invalid/releases/v0.4.0',
      ),
    );

    expect(find.text('Update fehlgeschlagen'), findsOneWidget);
    expect(find.text('Etwas ist schiefgelaufen.'), findsOneWidget);
    expect(find.text('https://example.invalid/releases/v0.4.0'), findsOneWidget);
    expect(find.text('Schließen'), findsOneWidget);
  });
}
