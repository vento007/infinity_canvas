part of '../node_canvas_demo.dart';

class _NodeCard extends StatefulWidget {
  final _Node node;
  final bool paintedSkin;
  final bool enableHover;
  final bool useMaterialActionButton;
  final VoidCallback? onBuilt;
  final ValueChanged<Offset> onResizeStart;
  final ValueChanged<Offset> onResizeUpdate;
  final ValueChanged<bool> onResizeEnd;
  final VoidCallback onActionTap;

  const _NodeCard({
    required this.node,
    required this.paintedSkin,
    required this.enableHover,
    required this.useMaterialActionButton,
    this.onBuilt,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onActionTap,
  });

  @override
  State<_NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<_NodeCard> {
  bool _hovered = false;
  bool _handleHovered = false;
  int? _activeResizePointer;

  void _onHandlePointerDown(PointerDownEvent event) {
    if (_activeResizePointer != null) return;
    _activeResizePointer = event.pointer;
    widget.onResizeStart(event.position);
  }

  void _onHandlePointerMove(PointerMoveEvent event) {
    if (_activeResizePointer != event.pointer) return;
    widget.onResizeUpdate(event.position);
  }

  void _onHandlePointerUp(PointerUpEvent event) {
    if (_activeResizePointer != event.pointer) return;
    _activeResizePointer = null;
    widget.onResizeEnd(false);
  }

  void _onHandlePointerCancel(PointerCancelEvent event) {
    if (_activeResizePointer != event.pointer) return;
    _activeResizePointer = null;
    widget.onResizeEnd(true);
  }

  @override
  void dispose() {
    _activeResizePointer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuilt?.call();
    return ValueListenableBuilder<Size>(
      valueListenable: widget.node.size,
      builder: (context, size, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: widget.node.dragging,
          builder: (context, dragging, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: widget.node.resizing,
              builder: (context, resizing, _) {
                final hotState = dragging || resizing || _hovered;
                final borderColor = resizing
                    ? const Color(0xFFFF7F11)
                    : (dragging
                          ? const Color(0xFFFFB703)
                          : (_hovered
                                ? const Color(0xFFFFC857)
                                : Colors.white.withValues(alpha: 0.18)));
                final borderWidth = hotState ? 3.0 : 1.0;
                final actionButton = widget.useMaterialActionButton
                    ? FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: widget.onActionTap,
                        child: const Text(
                          'Action',
                          style: TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : _LiteActionButton(onTap: widget.onActionTap);

                final content = Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.node.id,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Canvas drag + inner button + resize handle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            resizing
                                ? 'RESIZE: YES'
                                : (dragging
                                      ? 'DRAG: YES'
                                      : (_hovered
                                            ? 'HOVER: YES'
                                            : 'HOVER: NO')),
                            style: TextStyle(
                              color: hotState
                                  ? const Color(0xFFFFF0C1)
                                  : Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 24,
                            child: actionButton,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeDownRight,
                        onEnter: (_) {
                          if (_handleHovered) return;
                          setState(() => _handleHovered = true);
                        },
                        onExit: (_) {
                          if (!_handleHovered) return;
                          setState(() => _handleHovered = false);
                        },
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: _onHandlePointerDown,
                            onPointerMove: _onHandlePointerMove,
                            onPointerUp: _onHandlePointerUp,
                            onPointerCancel: _onHandlePointerCancel,
                            child: CustomPaint(
                              painter: _ResizeHandlePainter(
                                color: resizing || _handleHovered
                                    ? const Color(0xFFFFF0C1)
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                final card = widget.paintedSkin
                    ? CustomPaint(
                        painter: _NodeCardSkinPainter(
                          fillColor: widget.node.color,
                          borderColor: borderColor,
                          borderWidth: borderWidth,
                          hotState: hotState,
                        ),
                        child: content,
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.node.color,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: borderColor,
                            width: borderWidth,
                          ),
                          boxShadow: [
                            const BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                            if (hotState)
                              BoxShadow(
                                color: const Color(
                                  0xFFFFC857,
                                ).withValues(alpha: 0.35),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: content,
                      );

                final body = SizedBox(
                  width: size.width,
                  height: size.height,
                  child: card,
                );
                if (!widget.enableHover) {
                  return body;
                }
                return MouseRegion(
                  onEnter: (_) {
                    if (_hovered) return;
                    setState(() => _hovered = true);
                  },
                  onExit: (_) {
                    if (!_hovered) return;
                    setState(() => _hovered = false);
                  },
                  child: body,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ResizeHandlePainter extends CustomPainter {
  final Color color;

  const _ResizeHandlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.90),
      Offset(size.width * 0.90, size.height * 0.25),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.05, size.height * 0.90),
      Offset(size.width * 0.90, size.height * 0.05),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _ResizeHandlePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _NodeCardSkinPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool hotState;

  const _NodeCardSkinPainter({
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    required this.hotState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const radius = Radius.circular(10);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.26)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);

    if (hotState) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFFC857).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRRect(rrect.inflate(1), glowPaint);
    }

    canvas.drawRRect(rrect, Paint()..color = fillColor);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _NodeCardSkinPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.hotState != hotState;
  }
}

class _LiteActionButton extends StatefulWidget {
  final VoidCallback onTap;

  const _LiteActionButton({required this.onTap});

  @override
  State<_LiteActionButton> createState() => _LiteActionButtonState();
}

class _LiteActionButtonState extends State<_LiteActionButton> {
  int? _activePointer;
  Offset? _downGlobal;
  bool _pressed = false;
  static const double _tapSlop = 6.0;

  void _reset() {
    _activePointer = null;
    _downGlobal = null;
    if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _downGlobal = event.position;
    setState(() => _pressed = true);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer || _downGlobal == null) return;
    final moved = (event.position - _downGlobal!).distance;
    final shouldPress = moved <= _tapSlop;
    if (shouldPress != _pressed) {
      setState(() => _pressed = shouldPress);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer || _downGlobal == null) return;
    final moved = (event.position - _downGlobal!).distance;
    final isTap = moved <= _tapSlop;
    _reset();
    if (isTap) {
      widget.onTap();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _pressed ? 0.24 : 0.16),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: const Center(
          child: Text(
            'Action',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
