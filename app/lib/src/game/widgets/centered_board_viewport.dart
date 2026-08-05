import 'package:flutter/material.dart';

/// Ein [InteractiveViewer] (pan-/zoombar, `constrained: false`), das sich
/// beim allerersten Layout einmalig auf [focalPoint] zentriert, statt wie
/// standardmäßig oben links zu starten - `InteractiveViewer` selbst kennt
/// ohne einen [TransformationController] nur die Identitäts-Transformation
/// (Ursprung oben links).
///
/// Zentriert bewusst nur einmal (beim ersten Mount): [child] nutzt intern
/// ein festes Koordinatensystem (siehe `BoardGeometry`), sodass spätere
/// Steinplatzierungen bereits gezeichnete Inhalte nicht verschieben und ein
/// erneutes Zentrieren dafür auch nicht nötig ist.
class CenteredBoardViewport extends StatefulWidget {
  const CenteredBoardViewport({
    super.key,
    required this.contentSize,
    required this.focalPoint,
    required this.child,
  });

  final Size contentSize;

  /// Pixel-Punkt innerhalb von [child] (im festen Koordinatensystem), der
  /// beim ersten Layout in die Mitte des Viewports gerückt wird.
  final Offset focalPoint;
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
      final dx = viewportSize.width / 2 - widget.focalPoint.dx;
      final dy = viewportSize.height / 2 - widget.focalPoint.dy;
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
      boundaryMargin: const EdgeInsets.all(150),
      child: SizedBox(
        width: widget.contentSize.width,
        height: widget.contentSize.height,
        child: widget.child,
      ),
    );
  }
}
