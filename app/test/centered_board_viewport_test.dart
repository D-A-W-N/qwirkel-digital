import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/game/widgets/centered_board_viewport.dart';

void main() {
  testWidgets(
    'CenteredBoardViewport zentriert auf den Fokuspunkt beim ersten Layout statt oben links zu starten',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: CenteredBoardViewport(
                contentSize: const Size(2000, 1600),
                focalPoint: const Offset(1000, 800),
                child: Container(color: Colors.red),
              ),
            ),
          ),
        ),
      );

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final controller = viewer.transformationController!;

      final translation = controller.value.getTranslation();
      // Erwartete Zentrierung: Viewport (400x300) minus Fokuspunkt.
      expect(translation.x, closeTo(400 / 2 - 1000, 0.01));
      expect(translation.y, closeTo(300 / 2 - 800, 0.01));

      // Weiteres Pumpen (z. B. durch nachfolgende Inhaltsänderungen) darf
      // NICHT erneut zentrieren - das würde die Ansicht unter dem:der
      // Spieler:in wegschieben, sobald ein neuer Stein gelegt wird.
      controller.value = Matrix4.identity();
      await tester.pump();
      await tester.pump();
      expect(controller.value, Matrix4.identity());
    },
  );
}
