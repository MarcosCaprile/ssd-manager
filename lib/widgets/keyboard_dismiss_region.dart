import 'package:flutter/material.dart';

/// Removes text-input focus when a pointer is pressed outside the currently
/// focused editable area without competing with buttons and other gestures.
class KeyboardDismissRegion extends StatelessWidget {
  const KeyboardDismissRegion({required this.child, super.key});

  final Widget child;

  static void dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || !focus.hasFocus) return;

    final renderObject = focus.context?.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.attached &&
        renderObject.hasSize) {
      final localPosition = renderObject.globalToLocal(event.position);
      if (renderObject.size.contains(localPosition)) return;
    }

    focus.unfocus();
  }
}
