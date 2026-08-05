import 'package:flutter/material.dart';

/// Ein [InteractiveViewer] (pan-/zoombar, `constrained: false`), das sich
/// beim allerersten Layout einmalig auf die Mitte seines Inhalts zentriert,
/// statt wie standardmäßig oben links zu starten - `InteractiveViewer`
/// selbst kennt ohne einen [TransformationController] nur die
/// Identitäts-Transformation (Ursprung oben links).
///
/// Zentriert bewusst nur einmal (beim ersten Mount, nicht bei jeder
/// Änderung von [contentWidth]/[contentHeight]): sonst würde jede neue
/// Steinplatzierung - die die Inhaltsgröße meist vergrößert - die Ansicht
/// unter dem:der Spieler:in wegschieben.
class CenteredBoardViewport extends StatefulWidget {
  const CenteredBoardViewport({
    super.key,
    required this.contentWidth,
    required this.contentHeight,
    required this.child,
  });

  final double contentWidth;
  final double contentHeight;
  final Widget child;

  @override
  State<CenteredBoardViewport> createState() => _CenteredBoardViewportState();
}

class _CenteredBoardViewportState extends State<CenteredBoardViewport> {
  final _controller = TransformationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewportSize = context.size;
      if (viewportSize == null) return;
      final dx = viewportSize.width / 2 - widget.contentWidth / 2;
      final dy = viewportSize.height / 2 - widget.contentHeight / 2;
      _controller.value = Matrix4.identity()..translateByDouble(dx, dy, 0, 1);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      constrained: false,
      minScale: 0.4,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(400),
      child: widget.child,
    );
  }
}
