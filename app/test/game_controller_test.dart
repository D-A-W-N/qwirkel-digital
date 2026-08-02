import 'package:flutter_test/flutter_test.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'package:qwirkle_digital/src/game/game_controller.dart';

void main() {
  test('stageTile blockiert Zugpositionen, die eine Lücke in der Kette erzeugen', () {
    final game = QwirkleGame(players: [Player(id: 'p1', name: 'Anna')]);
    final controller = GameController(game);

    game.currentPlayer.hand = [
      const Tile(TileColor.red, TileShape.circle),
      const Tile(TileColor.red, TileShape.cross),
    ];
    game.board.apply([
      TilePlacement(
        position: const Position(0, 0),
        tile: const Tile(TileColor.red, TileShape.diamond),
      ),
    ]);

    controller.stageTile(0, const Position(1, 0));
    expect(controller.pendingPlacements, hasLength(1));

    controller.stageTile(1, const Position(3, 0));

    expect(controller.pendingPlacements, hasLength(1));
    expect(controller.lastError, isNotNull);
    expect(controller.lastError, contains('lückenlos'));
  });
}
