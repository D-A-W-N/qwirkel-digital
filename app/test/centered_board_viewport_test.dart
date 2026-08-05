import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_digital/src/game/widgets/centered_board_viewport.dart';

void main() {
  testWidgets(
    'CenteredBoardViewport zentriert den Inhalt beim ersten Layout statt oben links zu starten',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: CenteredBoardViewport(
                contentWidth: 1000,
                contentHeight: 800,
                child: Container(width: 1000, height: 800, color: Colors.red),
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
      // Erwartete Zentrierung: Viewport (400x300) minus halbe Inhaltsgröße.
      expect(translation.x, closeTo(400 / 2 - 1000 / 2, 0.01));
      expect(translation.y, closeTo(300 / 2 - 800 / 2, 0.01));

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
