import 'package:flutter/material.dart';

import '../node_model.dart';

class NodeCard extends StatefulWidget {
  final DemoNode node;
  final VoidCallback? onBuilt;
  final VoidCallback onActionTap;
  final ValueChanged<Offset> onResizeStart;
  final ValueChanged<Offset> onResizeUpdate;
  final ValueChanged<bool> onResizeEnd;

  const NodeCard({
    super.key,
    required this.node,
    this.onBuilt,
    required this.onActionTap,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  @override
  State<NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<NodeCard> {
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
    if (_activeResizePointer != null) {
      widget.onResizeEnd(true);
    }
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
                            'Widget node: hover + button + resize',
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
                                ? 'RESIZE'
                                : (dragging
                                      ? 'DRAG'
                                      : (_hovered ? 'HOVER' : 'IDLE')),
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
                            child: _LiteActionButton(onTap: widget.onActionTap),
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

                final body = SizedBox(
                  width: size.width,
                  height: size.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.node.color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: borderColor,
                        width: hotState ? 3.0 : 1.0,
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
                  ),
                );

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
